import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/live_classes/data/live_class_repository.dart';

void main() {
  group('LiveClassRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late LiveClassRepository repository;

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

      repository = LiveClassRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes live classes with queued sync operations',
      () async {
        await repository.saveClass(
          providerType: LiveClassRepository.zoomProvider,
          title: 'Math Revision',
          hostName: 'Ms. Mary',
          joinUrl: 'https://zoom.us/j/123456789',
        );

        final classes = await repository.watchZoomClasses().first;
        expect(classes.length, 1);

        await repository.deleteClass(classes.single);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 20,
          tenantId: tenantId,
        );
        final ops = queue
            .where((row) => row.entityType == 'live_class')
            .toList();

        expect(ops.length, 2);
        expect(ops.where((row) => row.operation == 'upsert').length, 1);
        expect(ops.where((row) => row.operation == 'delete').length, 1);
      },
    );
  });
}
