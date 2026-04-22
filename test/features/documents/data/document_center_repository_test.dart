import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/documents/data/document_center_repository.dart';

void main() {
  group('DocumentCenterRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late DocumentCenterRepository repository;

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

      repository = DocumentCenterRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes document center items with sync queue entries',
      () async {
        await repository.saveItem(
          contentType: DocumentCenterRepository.contentTypeMyDocument,
          title: 'Permission Slip',
          fileUrl: 'https://example.com/permission.pdf',
          uploadState: 'pending_upload',
        );

        final docs = await repository.watchMyDocuments().first;
        expect(docs.length, 1);

        await repository.deleteItem(docs.single);

        final queue = await database.getSyncQueueDispatchBatch(
          tenantId: tenantId,
          limit: 20,
        );
        final entries = queue
            .where((row) => row.entityType == 'document_center_item')
            .toList();

        expect(entries.length, 2);
        expect(entries.where((row) => row.operation == 'upsert').length, 1);
        expect(entries.where((row) => row.operation == 'delete').length, 1);
      },
    );
  });
}
