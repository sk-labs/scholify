import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/visitor_communication/data/visitor_communication_repository.dart';

void main() {
  group('VisitorCommunicationRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late VisitorCommunicationRepository repository;

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

      repository = VisitorCommunicationRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes visitor entries while queueing sync operations',
      () async {
        await repository.saveEntry(
          entryType: VisitorCommunicationRepository.visitorBookType,
          visitorName: 'John Doe',
          purpose: 'Campus visit',
          note: 'Walk-in parent',
        );

        final entries = await repository.watchVisitorBook().first;
        expect(entries.length, 1);

        await repository.deleteEntry(entries.single);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 20,
          tenantId: tenantId,
        );
        final ops = queue
            .where((row) => row.entityType == 'visitor_communication')
            .toList();

        expect(ops.length, 2);
        expect(ops.where((row) => row.operation == 'upsert').length, 1);
        expect(ops.where((row) => row.operation == 'delete').length, 1);
      },
    );
  });
}
