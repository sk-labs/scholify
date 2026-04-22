import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/library/data/library_repository.dart';

void main() {
  group('LibraryRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late LibraryRepository repository;

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

      repository = LibraryRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('creates and deletes library items with sync queue entries', () async {
      await repository.saveBook(
        title: 'Wings of Fire',
        bookType: LibraryRepository.issuedType,
        authorName: 'A.P.J. Abdul Kalam',
        issueCount: 12,
        isIssued: true,
      );

      final issued = await repository.watchIssuedBooks().first;
      expect(issued.length, 1);

      await repository.deleteBook(issued.single);

      final queue = await database.getSyncQueueDispatchBatch(
        tenantId: tenantId,
        limit: 20,
      );
      final entries = queue
          .where((row) => row.entityType == 'library_item')
          .toList();

      expect(entries.length, 2);
      expect(entries.where((row) => row.operation == 'upsert').length, 1);
      expect(entries.where((row) => row.operation == 'delete').length, 1);
    });
  });
}
