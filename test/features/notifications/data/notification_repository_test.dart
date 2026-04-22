import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/notifications/data/notification_repository.dart';

void main() {
  group('NotificationRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late NotificationRepository repository;

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

      repository = NotificationRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('queues create, read-mark, and delete operations', () async {
      await repository.saveNotification(
        title: 'Holiday Circular',
        body: 'School closed on Friday.',
        notificationType: 'event',
      );

      final rows = await repository.watchNotifications().first;
      expect(rows.length, 1);
      expect(rows.single.isRead, isFalse);

      await repository.markRead(rows.single);
      final afterRead = await repository.watchNotifications().first;
      expect(afterRead.single.isRead, isTrue);

      await repository.deleteNotification(afterRead.single);

      final queue = await database.getSyncQueueDispatchBatch(
        limit: 20,
        tenantId: tenantId,
      );
      final ops = queue
          .where((row) => row.entityType == 'notification')
          .toList();

      expect(ops.length, 3);
      expect(ops.where((row) => row.operation == 'upsert').length, 2);
      expect(ops.where((row) => row.operation == 'delete').length, 1);
    });
  });
}
