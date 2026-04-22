import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class OnlineLearningRepository {
  OnlineLearningRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String courseType = 'course';
  static const String quizType = 'quiz';

  Stream<List<OnlineLearningEntry>> watchItems({
    String? itemType,
    bool includeInactive = false,
  }) {
    return database.watchOnlineLearningItems(
      tenantId: _resolveTenantId(),
      itemType: itemType,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveItem({
    String? itemId,
    required String itemType,
    required String title,
    String? summary,
    String? instructorName,
    String? durationLabel,
    String accessLevel = 'open',
    double priceAmount = 0,
    DateTime? publishedAt,
    bool isPublished = true,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId = itemId ?? 'ol_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertOnlineLearningItemRecord(
      itemId: resolvedId,
      tenantId: tenantId,
      itemType: itemType,
      title: title,
      summary: summary,
      instructorName: instructorName,
      durationLabel: durationLabel,
      accessLevel: accessLevel,
      priceAmount: priceAmount,
      publishedAt: publishedAt?.toUtc(),
      isPublished: isPublished,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_learning_item',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'itemId': resolvedId,
        'tenantId': tenantId,
        'itemType': itemType,
        'title': title,
        'summary': summary,
        'instructorName': instructorName,
        'durationLabel': durationLabel,
        'accessLevel': accessLevel,
        'priceAmount': priceAmount,
        'publishedAt': publishedAt?.toUtc().toIso8601String(),
        'isPublished': isPublished,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteItem(OnlineLearningEntry item) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteOnlineLearningItemRecord(
      tenantId: tenantId,
      itemId: item.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_learning_item',
      entityId: item.id,
      operation: 'delete',
      payload: jsonEncode({
        'itemId': item.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  // ── Attempt lifecycle ─────────────────────────────────────────────────────

  Stream<List<OnlineLearningAttemptEntry>> watchItemAttempts({
    required String itemId,
  }) {
    return database.watchItemAttempts(
      tenantId: _resolveTenantId(),
      itemId: itemId,
    );
  }

  Stream<List<OnlineLearningAttemptEntry>> watchStudentAttempts({
    required String studentId,
  }) {
    return database.watchStudentAttempts(
      tenantId: _resolveTenantId(),
      studentId: studentId,
    );
  }

  Future<void> startAttempt({
    required String itemId,
    required String studentId,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final attemptId = 'att_${itemId}_${studentId}_${now.millisecondsSinceEpoch}';

    await database.upsertOnlineLearningAttemptRecord(
      attemptId: attemptId,
      tenantId: tenantId,
      itemId: itemId,
      studentId: studentId,
      attemptStatus: 'in_progress',
      startedAt: now,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_learning_attempt',
      entityId: attemptId,
      operation: 'upsert',
      payload: jsonEncode({
        'attemptId': attemptId,
        'tenantId': tenantId,
        'itemId': itemId,
        'studentId': studentId,
        'attemptStatus': 'in_progress',
        'startedAt': now.toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> completeAttempt({
    required OnlineLearningAttemptEntry attempt,
    required double scorePercent,
    required int durationSeconds,
    required bool isPassed,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.upsertOnlineLearningAttemptRecord(
      attemptId: attempt.id,
      tenantId: tenantId,
      itemId: attempt.itemId,
      studentId: attempt.studentId,
      attemptStatus: 'completed',
      scorePercent: scorePercent,
      durationSeconds: durationSeconds,
      startedAt: attempt.startedAt,
      completedAt: now,
      isPassed: isPassed,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_learning_attempt',
      entityId: attempt.id,
      operation: 'upsert',
      payload: jsonEncode({
        'attemptId': attempt.id,
        'tenantId': tenantId,
        'itemId': attempt.itemId,
        'studentId': attempt.studentId,
        'attemptStatus': 'completed',
        'scorePercent': scorePercent,
        'durationSeconds': durationSeconds,
        'startedAt': attempt.startedAt?.toIso8601String(),
        'completedAt': now.toIso8601String(),
        'isPassed': isPassed,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteAttempt(OnlineLearningAttemptEntry attempt) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteOnlineLearningAttemptRecord(
      tenantId: tenantId,
      attemptId: attempt.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_learning_attempt',
      entityId: attempt.id,
      operation: 'delete',
      payload: jsonEncode({
        'attemptId': attempt.id,
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
