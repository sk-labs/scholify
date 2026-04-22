import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class OnlineExamRepository {
  OnlineExamRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  /// Watch all exams. Pass [isSubmitted] to filter upcoming vs closed.
  Stream<List<OnlineExamEntry>> watchExams({bool? isSubmitted}) {
    return database.watchOnlineExams(
      tenantId: _tid(),
      isSubmitted: isSubmitted,
    );
  }

  Future<void> saveExam({
    String? examId,
    required String examTitle,
    String? description,
    String? examFrom,
    String? examTo,
    int totalQuestions = 0,
    int totalAttempt = 1,
    int durationMinutes = 0,
    double passingPercent = 35,
    bool isQuiz = false,
    String statusLabel = 'upcoming',
  }) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();
    final resolvedId =
        examId ?? 'oex_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertOnlineExamRecord(
      examId: resolvedId,
      tenantId: tenantId,
      examTitle: examTitle,
      description: description,
      examFrom: examFrom,
      examTo: examTo,
      totalQuestions: totalQuestions,
      totalAttempt: totalAttempt,
      durationMinutes: durationMinutes,
      passingPercent: passingPercent,
      isQuiz: isQuiz,
      statusLabel: statusLabel,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_exam',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'examId': resolvedId,
        'tenantId': tenantId,
        'examTitle': examTitle,
        'description': description,
        'examFrom': examFrom,
        'examTo': examTo,
        'totalQuestions': totalQuestions,
        'totalAttempt': totalAttempt,
        'durationMinutes': durationMinutes,
        'passingPercent': passingPercent,
        'isQuiz': isQuiz,
        'statusLabel': statusLabel,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  /// Record a submission result for an exam (updates attempt count, score, pass state).
  Future<void> submitExam({
    required OnlineExamEntry exam,
    required double scorePercent,
  }) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();
    final isPassed = scorePercent >= exam.passingPercent;

    await database.upsertOnlineExamRecord(
      examId: exam.id,
      tenantId: tenantId,
      examTitle: exam.examTitle,
      description: exam.description,
      examFrom: exam.examFrom,
      examTo: exam.examTo,
      totalQuestions: exam.totalQuestions,
      totalAttempt: exam.totalAttempt,
      durationMinutes: exam.durationMinutes,
      passingPercent: exam.passingPercent,
      isQuiz: exam.isQuiz,
      statusLabel: 'submitted',
      attemptCount: exam.attemptCount + 1,
      isSubmitted: true,
      lastScorePercent: scorePercent,
      isPassed: isPassed,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_exam',
      entityId: exam.id,
      operation: 'upsert',
      payload: jsonEncode({
        'examId': exam.id,
        'tenantId': tenantId,
        'examTitle': exam.examTitle,
        'statusLabel': 'submitted',
        'attemptCount': exam.attemptCount + 1,
        'isSubmitted': true,
        'lastScorePercent': scorePercent,
        'isPassed': isPassed,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteExam(OnlineExamEntry exam) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.deleteOnlineExamRecord(
      tenantId: tenantId,
      examId: exam.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_exam',
      entityId: exam.id,
      operation: 'delete',
      payload: jsonEncode({
        'examId': exam.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _tid() {
    final id = tenantContext.tenantId;
    return (id != null && id.isNotEmpty) ? id : 'school_demo';
  }
}
