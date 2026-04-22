import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/timetable/data/timetable_repository.dart';

void main() {
  group('TimetableRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late TimetableRepository repository;

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

      repository = TimetableRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes slots while queueing timetable sync operations',
      () async {
        await repository.saveSlot(
          dayOfWeek: 'Monday',
          periodIndex: 1,
          subjectName: 'Mathematics',
          teacherName: 'Mr. Raman',
          roomNo: 'A-101',
          timeFrom: '08:30',
          timeTo: '09:10',
        );

        await repository.saveSlot(
          dayOfWeek: 'Tuesday',
          periodIndex: 2,
          subjectName: 'Science',
          teacherName: 'Ms. Khan',
          roomNo: 'B-202',
          timeFrom: '09:20',
          timeTo: '10:00',
        );

        final monday = await repository.watchDaySlots('Monday').first;
        expect(monday.length, 1);
        expect(monday.single.subjectName, 'Mathematics');

        final allRows = await repository.watchWeekSlots().first;
        expect(allRows.length, 2);

        await repository.deleteSlot(monday.single);

        final mondayAfterDelete = await repository
            .watchDaySlots('Monday')
            .first;
        expect(mondayAfterDelete, isEmpty);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );
        final timetableOps = queue
            .where((entry) => entry.entityType == 'timetable_slot')
            .toList();

        expect(timetableOps.length, 3);
        expect(
          timetableOps.where((entry) => entry.operation == 'upsert').length,
          2,
        );
        expect(
          timetableOps.where((entry) => entry.operation == 'delete').length,
          1,
        );
      },
    );
  });
}
