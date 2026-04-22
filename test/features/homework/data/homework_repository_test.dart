import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/homework/data/homework_repository.dart';

void main() {
  group('HomeworkRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late HomeworkRepository repository;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
      tenantContext = TenantContext()
        ..setTenant(
          tenantId: tenantId,
          tenantName: 'Alpha School',
          role: 'school_owner',
          isSuperAdmin: false,
        );

      syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: PocketbaseGateway(baseUrl: 'http://127.0.0.1:8090'),
        tenantContext: tenantContext,
      );

      repository = HomeworkRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes assignments while queueing homework sync operations',
      () async {
        await repository.saveAssignment(
          assignmentType: HomeworkRepository.homeworkType,
          title: 'Math Worksheet',
          subjectName: 'Mathematics',
          classSection: '7-A',
          details: 'Complete questions 1-10',
          dueDate: DateTime.utc(2026, 7, 5),
        );

        await repository.saveAssignment(
          assignmentType: HomeworkRepository.dailyAssignmentType,
          title: 'Science Observation',
          subjectName: 'Science',
          classSection: '7-A',
          details: 'Record weather for 5 days',
          dueDate: DateTime.utc(2026, 7, 7),
        );

        final homework = await repository
            .watchAssignments(assignmentType: HomeworkRepository.homeworkType)
            .first;
        expect(homework.length, 1);
        expect(homework.single.title, 'Math Worksheet');

        final daily = await repository
            .watchAssignments(
              assignmentType: HomeworkRepository.dailyAssignmentType,
            )
            .first;
        expect(daily.length, 1);

        await repository.deleteAssignment(homework.single);

        final homeworkAfterDelete = await repository
            .watchAssignments(assignmentType: HomeworkRepository.homeworkType)
            .first;
        expect(homeworkAfterDelete, isEmpty);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );
        final ops = queue
            .where((entry) => entry.entityType == 'homework_assignment')
            .toList();

        expect(ops.length, 3);
        expect(ops.where((entry) => entry.operation == 'upsert').length, 2);
        expect(ops.where((entry) => entry.operation == 'delete').length, 1);
      },
    );
  });
}
