import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class NoticeBoardRepository {
  NoticeBoardRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<NoticeBoardEntry>> watchNotices({bool publishedOnly = true}) {
    return database.watchNoticeBoardEntries(
      tenantId: _resolveTenantId(),
      publishedOnly: publishedOnly,
    );
  }

  Future<void> saveNotice({
    String? noticeId,
    required String title,
    required String message,
    String audience = 'all',
    DateTime? publishAt,
    DateTime? expiresAt,
    bool isPublished = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedNoticeId =
        noticeId ?? 'notice_${tenantId}_${now.millisecondsSinceEpoch}';
    final resolvedPublishAt = (publishAt ?? now).toUtc();

    await database.upsertNoticeBoardRecord(
      noticeId: resolvedNoticeId,
      tenantId: tenantId,
      title: title,
      message: message,
      audience: audience,
      publishAt: resolvedPublishAt,
      expiresAt: expiresAt?.toUtc(),
      isPublished: isPublished,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'notice_board',
      entityId: resolvedNoticeId,
      operation: 'upsert',
      payload: jsonEncode({
        'noticeId': resolvedNoticeId,
        'tenantId': tenantId,
        'title': title,
        'message': message,
        'audience': audience,
        'publishAt': resolvedPublishAt.toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'isPublished': isPublished,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteNotice(NoticeBoardEntry notice) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteNoticeBoardRecord(
      tenantId: tenantId,
      noticeId: notice.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'notice_board',
      entityId: notice.id,
      operation: 'delete',
      payload: jsonEncode({
        'noticeId': notice.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}
