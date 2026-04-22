import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class CbseExamRepository {
  CbseExamRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String typeResult = 'result';
  static const String typeSchedule = 'schedule';

  Stream<List<CbseExamResultEntry>> watchResults({
    String resultType = typeResult,
  }) {
    return database.watchCbseExamResults(
      tenantId: _tid(),
      studentId: _studentId(),
      resultType: resultType,
    );
  }

  Future<void> saveResult({
    String? resultId,
    required String examName,
    required String subjectName,
    String? subjectCode,
    String? assessmentName,
    double? marksObtained,
    double? maxMarks,
    String? examDate,
    String? grade,
    String? rank,
    String? percentage,
    String? totalObtained,
    String? totalMax,
    String resultType = typeResult,
    String? roomNo,
    String? timeFrom,
    String? duration,
  }) async {
    final tenantId = _tid();
    final studentId = _studentId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        resultId ??
        'cbse_${tenantId}_${studentId}_${examName}_${subjectName}_${now.millisecondsSinceEpoch}'
            .replaceAll(' ', '_');

    await database.upsertCbseExamResultRecord(
      resultId: resolvedId,
      tenantId: tenantId,
      studentId: studentId,
      examName: examName,
      subjectName: subjectName,
      subjectCode: subjectCode,
      assessmentName: assessmentName,
      marksObtained: marksObtained,
      maxMarks: maxMarks,
      examDate: examDate,
      grade: grade,
      rank: rank,
      percentage: percentage,
      totalObtained: totalObtained,
      totalMax: totalMax,
      resultType: resultType,
      roomNo: roomNo,
      timeFrom: timeFrom,
      duration: duration,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'cbse_exam_result',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'resultId': resolvedId,
        'tenantId': tenantId,
        'studentId': studentId,
        'examName': examName,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'assessmentName': assessmentName,
        'marksObtained': marksObtained,
        'maxMarks': maxMarks,
        'examDate': examDate,
        'grade': grade,
        'rank': rank,
        'percentage': percentage,
        'resultType': resultType,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteResult(CbseExamResultEntry entry) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.deleteCbseExamResultRecord(
      tenantId: tenantId,
      resultId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'cbse_exam_result',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'resultId': entry.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _tid() {
    final id = tenantContext.tenantId;
    return (id != null && id.isNotEmpty) ? id : 'school_demo';
  }

  String _studentId() {
    return tenantContext.tenantId ?? 'student_demo';
  }
}
