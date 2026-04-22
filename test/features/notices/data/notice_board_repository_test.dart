import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/notices/data/notice_board_repository.dart';

void main() {
  group('NoticeBoardRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late NoticeBoardRepository repository;

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

      repository = NoticeBoardRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('creates and deletes notice while queueing sync operations', () async {
      await repository.saveNotice(
        title: 'PTM Schedule',
        message: 'Parent teacher meeting on Friday at 10 AM.',
        audience: 'parents',
        isPublished: true,
      );

      final notices = await repository.watchNotices(publishedOnly: false).first;
      expect(notices.length, 1);
      expect(notices.single.title, 'PTM Schedule');
      expect(notices.single.audience, 'parents');

      await repository.deleteNotice(notices.single);

      final afterDelete = await repository
          .watchNotices(publishedOnly: false)
          .first;
      expect(afterDelete, isEmpty);

      final queue = await database.getSyncQueueDispatchBatch(
        limit: 50,
        tenantId: tenantId,
      );

      final noticeOps = queue
          .where((entry) => entry.entityType == 'notice_board')
          .toList();
      expect(noticeOps.length, 2);
      expect(noticeOps.first.operation, 'upsert');
      expect(noticeOps.last.operation, 'delete');
    });
  });
}
