import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/online_learning/data/online_learning_repository.dart';

void main() {
  group('OnlineLearningRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late OnlineLearningRepository repository;

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

      repository = OnlineLearningRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes online learning items while queueing sync ops',
      () async {
        await repository.saveItem(
          itemType: OnlineLearningRepository.courseType,
          title: 'Algebra Foundation',
          instructorName: 'Dr. Rao',
          durationLabel: '4h',
          accessLevel: 'open',
          priceAmount: 0,
        );

        await repository.saveItem(
          itemType: OnlineLearningRepository.quizType,
          title: 'Algebra Quiz 1',
          instructorName: 'Dr. Rao',
          durationLabel: '20m',
          accessLevel: 'enrolled',
          priceAmount: 0,
        );

        final courses = await repository
            .watchItems(itemType: OnlineLearningRepository.courseType)
            .first;
        expect(courses.length, 1);
        expect(courses.single.title, 'Algebra Foundation');

        await repository.deleteItem(courses.single);

        final courseAfterDelete = await repository
            .watchItems(itemType: OnlineLearningRepository.courseType)
            .first;
        expect(courseAfterDelete, isEmpty);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );
        final ops = queue
            .where((entry) => entry.entityType == 'online_learning_item')
            .toList();

        expect(ops.length, 3);
        expect(ops.where((entry) => entry.operation == 'upsert').length, 2);
        expect(ops.where((entry) => entry.operation == 'delete').length, 1);
      },
    );
  });
}
