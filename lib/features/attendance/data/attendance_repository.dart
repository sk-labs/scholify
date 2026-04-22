import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class AttendanceRepository {
  AttendanceRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<StudentDirectoryEntry>> watchStudents() {
    return database.watchActiveStudentProfiles(tenantId: _resolveTenantId());
  }

  Stream<List<StudentAttendanceRecord>> watchStudentMonth({
    required String studentId,
    required DateTime month,
  }) {
    final normalizedMonth = DateTime(month.year, month.month, 1);
    final start = DateTime(normalizedMonth.year, normalizedMonth.month, 1);
    final end = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    final tenantId = _resolveTenantId();
    return database.watchStudentAttendanceRange(
      tenantId: tenantId,
      studentId: studentId,
      from: start,
      to: end,
    );
  }

  Future<void> markAttendance({
    required String studentId,
    required DateTime attendanceDate,
    required String status,
  }) async {
    final tenantId = _resolveTenantId();
    final dateKey = DateTime(
      attendanceDate.year,
      attendanceDate.month,
      attendanceDate.day,
    ).toUtc().toIso8601String().split('T').first;
    final recordId = 'att_${tenantId}_${studentId}_$dateKey';
    final now = DateTime.now().toUtc();

    await database.upsertStudentAttendanceRecord(
      recordId: recordId,
      tenantId: tenantId,
      studentId: studentId,
      attendanceDate: attendanceDate,
      status: status,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'student_attendance',
      entityId: recordId,
      operation: 'upsert',
      payload: jsonEncode({
        'recordId': recordId,
        'tenantId': tenantId,
        'studentId': studentId,
        'attendanceDate': attendanceDate.toUtc().toIso8601String(),
        'status': status,
        'source': 'local',
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
