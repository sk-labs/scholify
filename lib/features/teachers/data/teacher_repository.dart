import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class TeacherRepository {
  TeacherRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<TeacherEntry>> watchTeachers() {
    return database.watchTeachers(tenantId: _tid());
  }

  Future<void> submitReview({
    required TeacherEntry teacher,
    required int ratingScore,
    String? reviewComment,
  }) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.upsertTeacherRecord(
      teacherId: teacher.id,
      tenantId: tenantId,
      fullName: teacher.fullName,
      employeeNo: teacher.employeeNo,
      subjectName: teacher.subjectName,
      qualification: teacher.qualification,
      email: teacher.email,
      phone: teacher.phone,
      designation: teacher.designation,
      isClassTeacher: teacher.isClassTeacher,
      imageUrl: teacher.imageUrl,
      ratingScore: ratingScore,
      reviewComment: reviewComment,
      hasReviewed: true,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'teacher',
      entityId: teacher.id,
      operation: 'upsert',
      payload: jsonEncode({
        'teacherId': teacher.id,
        'tenantId': tenantId,
        'fullName': teacher.fullName,
        'ratingScore': ratingScore,
        'reviewComment': reviewComment,
        'hasReviewed': true,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _tid() {
    final id = tenantContext.tenantId;
    return (id != null && id.isNotEmpty) ? id : 'school_demo';
  }
}
