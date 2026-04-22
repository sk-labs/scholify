import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class NotificationRepository {
  NotificationRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<NotificationEntry>> watchNotifications({
    bool unreadOnly = false,
    bool includeInactive = false,
  }) {
    return database.watchNotifications(
      tenantId: _resolveTenantId(),
      unreadOnly: unreadOnly,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveNotification({
    String? notificationId,
    required String title,
    required String notificationType,
    String? body,
    String audience = 'all',
    String deliveryStatus = 'queued',
    String? payloadJson,
    bool isRead = false,
    bool isActive = true,
    DateTime? sentAt,
    DateTime? readAt,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        notificationId ?? 'notif_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertNotificationRecord(
      notificationId: resolvedId,
      tenantId: tenantId,
      notificationType: notificationType,
      title: title,
      body: body,
      audience: audience,
      isRead: isRead,
      deliveryStatus: deliveryStatus,
      sentAt: sentAt?.toUtc() ?? now,
      readAt: readAt?.toUtc(),
      payloadJson: payloadJson,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'notification',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'notificationId': resolvedId,
        'tenantId': tenantId,
        'notificationType': notificationType,
        'title': title,
        'body': body,
        'audience': audience,
        'isRead': isRead,
        'deliveryStatus': deliveryStatus,
        'sentAt': (sentAt?.toUtc() ?? now).toIso8601String(),
        'readAt': readAt?.toUtc().toIso8601String(),
        'payloadJson': payloadJson,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> markRead(NotificationEntry entry) async {
    if (entry.isRead) {
      return;
    }

    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.markNotificationRead(
      tenantId: tenantId,
      notificationId: entry.id,
      readAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'notification',
      entityId: entry.id,
      operation: 'upsert',
      payload: jsonEncode({
        'notificationId': entry.id,
        'tenantId': tenantId,
        'notificationType': entry.notificationType,
        'title': entry.title,
        'body': entry.body,
        'audience': entry.audience,
        'isRead': true,
        'deliveryStatus': 'read',
        'sentAt': entry.sentAt?.toUtc().toIso8601String(),
        'readAt': now.toIso8601String(),
        'payloadJson': entry.payloadJson,
        'isActive': entry.isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteNotification(NotificationEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteNotificationRecord(
      tenantId: tenantId,
      notificationId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'notification',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'notificationId': entry.id,
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
