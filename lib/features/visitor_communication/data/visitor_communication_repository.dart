import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class VisitorCommunicationRepository {
  VisitorCommunicationRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String visitorBookType = 'visitor_book';
  static const String timelineType = 'timeline';
  static const String commentType = 'comment';

  Stream<List<VisitorCommunicationEntry>> watchVisitorBook({
    bool includeInactive = false,
  }) {
    return database.watchVisitorCommunicationEntries(
      tenantId: _resolveTenantId(),
      entryType: visitorBookType,
      includeInactive: includeInactive,
    );
  }

  Stream<List<VisitorCommunicationEntry>> watchTimeline({
    bool includeInactive = false,
  }) {
    return database.watchVisitorCommunicationEntries(
      tenantId: _resolveTenantId(),
      entryType: timelineType,
      includeInactive: includeInactive,
    );
  }

  Stream<List<VisitorCommunicationEntry>> watchComments({
    bool includeInactive = false,
  }) {
    return database.watchVisitorCommunicationEntries(
      tenantId: _resolveTenantId(),
      entryType: commentType,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveEntry({
    String? entryId,
    required String entryType,
    String? visitorName,
    String? purpose,
    String? phone,
    String? note,
    String statusLabel = 'open',
    DateTime? checkInAt,
    DateTime? checkOutAt,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        entryId ?? 'visit_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertVisitorCommunicationRecord(
      entryId: resolvedId,
      tenantId: tenantId,
      entryType: entryType,
      visitorName: visitorName,
      purpose: purpose,
      phone: phone,
      note: note,
      statusLabel: statusLabel,
      checkInAt: checkInAt?.toUtc() ?? now,
      checkOutAt: checkOutAt?.toUtc(),
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'visitor_communication',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'entryId': resolvedId,
        'tenantId': tenantId,
        'entryType': entryType,
        'visitorName': visitorName,
        'purpose': purpose,
        'phone': phone,
        'note': note,
        'statusLabel': statusLabel,
        'checkInAt': (checkInAt?.toUtc() ?? now).toIso8601String(),
        'checkOutAt': checkOutAt?.toUtc().toIso8601String(),
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteEntry(VisitorCommunicationEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteVisitorCommunicationRecord(
      tenantId: tenantId,
      entryId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'visitor_communication',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'entryId': entry.id,
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
