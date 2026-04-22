import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class HomeworkRepository {
  HomeworkRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String homeworkType = 'homework';
  static const String dailyAssignmentType = 'daily_assignment';

  Stream<List<HomeworkAssignmentEntry>> watchAssignments({
    String? assignmentType,
    bool includeInactive = false,
  }) {
    return database.watchHomeworkAssignments(
      tenantId: _resolveTenantId(),
      assignmentType: assignmentType,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveAssignment({
    String? assignmentId,
    required String assignmentType,
    required String title,
    String? subjectName,
    String? classSection,
    String? details,
    DateTime? assignedOn,
    DateTime? dueDate,
    String? attachmentUrl,
    bool isPublished = true,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        assignmentId ?? 'hw_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertHomeworkAssignmentRecord(
      assignmentId: resolvedId,
      tenantId: tenantId,
      assignmentType: assignmentType,
      title: title,
      subjectName: subjectName,
      classSection: classSection,
      details: details,
      assignedOn: assignedOn?.toUtc(),
      dueDate: dueDate?.toUtc(),
      attachmentUrl: attachmentUrl,
      isPublished: isPublished,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'homework_assignment',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'assignmentId': resolvedId,
        'tenantId': tenantId,
        'assignmentType': assignmentType,
        'title': title,
        'subjectName': subjectName,
        'classSection': classSection,
        'details': details,
        'assignedOn': assignedOn?.toUtc().toIso8601String(),
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'attachmentUrl': attachmentUrl,
        'isPublished': isPublished,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteAssignment(HomeworkAssignmentEntry assignment) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteHomeworkAssignmentRecord(
      tenantId: tenantId,
      assignmentId: assignment.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'homework_assignment',
      entityId: assignment.id,
      operation: 'delete',
      payload: jsonEncode({
        'assignmentId': assignment.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  // ── Submission lifecycle ──────────────────────────────────────────────────

  Stream<List<HomeworkSubmissionEntry>> watchSubmissions({
    required String assignmentId,
  }) {
    return database.watchHomeworkSubmissions(
      tenantId: _resolveTenantId(),
      assignmentId: assignmentId,
    );
  }

  Future<void> submitHomework({
    required String assignmentId,
    required String studentId,
    String? submissionText,
    String? attachmentUrl,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final submissionId = 'sub_${assignmentId}_$studentId';

    await database.upsertHomeworkSubmissionRecord(
      submissionId: submissionId,
      tenantId: tenantId,
      assignmentId: assignmentId,
      studentId: studentId,
      submissionText: submissionText,
      attachmentUrl: attachmentUrl,
      statusLabel: 'submitted',
      submittedAt: now,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'homework_submission',
      entityId: submissionId,
      operation: 'upsert',
      payload: jsonEncode({
        'submissionId': submissionId,
        'tenantId': tenantId,
        'assignmentId': assignmentId,
        'studentId': studentId,
        'submissionText': submissionText,
        'attachmentUrl': attachmentUrl,
        'statusLabel': 'submitted',
        'submittedAt': now.toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> reviewSubmission({
    required HomeworkSubmissionEntry submission,
    required String statusLabel,
    String? teacherFeedback,
    double? gradeScore,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.upsertHomeworkSubmissionRecord(
      submissionId: submission.id,
      tenantId: tenantId,
      assignmentId: submission.assignmentId,
      studentId: submission.studentId,
      submissionText: submission.submissionText,
      attachmentUrl: submission.attachmentUrl,
      statusLabel: statusLabel,
      teacherFeedback: teacherFeedback,
      gradeScore: gradeScore,
      submittedAt: submission.submittedAt,
      reviewedAt: now,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'homework_submission',
      entityId: submission.id,
      operation: 'upsert',
      payload: jsonEncode({
        'submissionId': submission.id,
        'tenantId': tenantId,
        'assignmentId': submission.assignmentId,
        'studentId': submission.studentId,
        'submissionText': submission.submissionText,
        'attachmentUrl': submission.attachmentUrl,
        'statusLabel': statusLabel,
        'teacherFeedback': teacherFeedback,
        'gradeScore': gradeScore,
        'submittedAt': submission.submittedAt?.toIso8601String(),
        'reviewedAt': now.toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteSubmission(HomeworkSubmissionEntry submission) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteHomeworkSubmissionRecord(
      tenantId: tenantId,
      submissionId: submission.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'homework_submission',
      entityId: submission.id,
      operation: 'delete',
      payload: jsonEncode({
        'submissionId': submission.id,
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
