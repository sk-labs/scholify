import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class PendingTaskRepository {
  PendingTaskRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<PendingTaskEntry>> watchPendingTasks({
    bool includeInactive = false,
  }) {
    return database.watchPendingTasks(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Future<void> saveTask({
    String? taskId,
    String? userId,
    required String title,
    DateTime? dueDate,
    String statusLabel = 'pending',
    bool isCompleted = false,
    String priority = 'medium',
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        taskId ?? 'task_${tenantId}_${now.microsecondsSinceEpoch}';
    final resolvedStatus = isCompleted ? 'completed' : statusLabel;

    await database.upsertPendingTaskRecord(
      taskId: resolvedId,
      tenantId: tenantId,
      userId: userId,
      title: title,
      dueDate: dueDate?.toUtc(),
      statusLabel: resolvedStatus,
      isCompleted: isCompleted,
      priority: priority,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'pending_task',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'taskId': resolvedId,
        'tenantId': tenantId,
        'userId': userId,
        'title': title,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'statusLabel': resolvedStatus,
        'isCompleted': isCompleted,
        'priority': priority,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> toggleCompletion(PendingTaskEntry entry) async {
    await saveTask(
      taskId: entry.id,
      userId: entry.userId,
      title: entry.title,
      dueDate: entry.dueDate,
      statusLabel: entry.isCompleted ? 'pending' : 'completed',
      isCompleted: !entry.isCompleted,
      priority: entry.priority,
      isActive: entry.isActive,
    );
  }

  Future<void> deleteTask(PendingTaskEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deletePendingTaskRecord(
      tenantId: tenantId,
      taskId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'pending_task',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'taskId': entry.id,
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
