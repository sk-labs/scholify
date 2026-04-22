import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class LeaveRequestRepository {
  LeaveRequestRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<LeaveRequestEntry>> watchLeaveRequests({
    bool includeInactive = false,
  }) {
    return database.watchLeaveRequests(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Future<void> saveLeaveRequest({
    String? leaveId,
    String? requesterId,
    DateTime? leaveFrom,
    DateTime? leaveTo,
    DateTime? appliedAt,
    String? reason,
    String statusLabel = 'pending',
    String? approverName,
    DateTime? approvedAt,
    String? attachmentUrl,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        leaveId ?? 'leave_${tenantId}_${now.microsecondsSinceEpoch}';
    final resolvedAppliedAt = appliedAt?.toUtc() ?? now;

    await database.upsertLeaveRequestRecord(
      leaveId: resolvedId,
      tenantId: tenantId,
      requesterId: requesterId,
      leaveFrom: leaveFrom?.toUtc(),
      leaveTo: leaveTo?.toUtc(),
      appliedAt: resolvedAppliedAt,
      reason: reason,
      statusLabel: statusLabel,
      approverName: approverName,
      approvedAt: approvedAt?.toUtc(),
      attachmentUrl: attachmentUrl,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'leave_request',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'leaveId': resolvedId,
        'tenantId': tenantId,
        'requesterId': requesterId,
        'leaveFrom': leaveFrom?.toUtc().toIso8601String(),
        'leaveTo': leaveTo?.toUtc().toIso8601String(),
        'appliedAt': resolvedAppliedAt.toIso8601String(),
        'reason': reason,
        'statusLabel': statusLabel,
        'approverName': approverName,
        'approvedAt': approvedAt?.toUtc().toIso8601String(),
        'attachmentUrl': attachmentUrl,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> approveLeaveRequest({
    required LeaveRequestEntry entry,
    String? approverName,
  }) async {
    await saveLeaveRequest(
      leaveId: entry.id,
      requesterId: entry.requesterId,
      leaveFrom: entry.leaveFrom,
      leaveTo: entry.leaveTo,
      appliedAt: entry.appliedAt,
      reason: entry.reason,
      statusLabel: 'approved',
      approverName: approverName ?? entry.approverName,
      approvedAt: DateTime.now().toUtc(),
      attachmentUrl: entry.attachmentUrl,
      isActive: entry.isActive,
    );
  }

  Future<void> deleteLeaveRequest(LeaveRequestEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteLeaveRequestRecord(
      tenantId: tenantId,
      leaveId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'leave_request',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'leaveId': entry.id,
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
