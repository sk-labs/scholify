import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class StudentRepository {
  StudentRepository({
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

  Stream<List<StudentGuardianEntry>> watchStudentGuardians({
    required String studentId,
    bool? isActive,
  }) {
    return database.watchStudentGuardians(
      tenantId: _resolveTenantId(),
      studentId: studentId,
      isActive: isActive,
    );
  }

  Stream<List<StudentEnrollmentEntry>> watchStudentEnrollments({
    required String studentId,
    String? academicSession,
  }) {
    return database.watchStudentEnrollments(
      tenantId: _resolveTenantId(),
      studentId: studentId,
      academicSession: academicSession,
    );
  }

  Stream<List<StudentClassRollEntry>> watchStudentClassRolls({
    required String studentId,
    String? academicSession,
  }) {
    return database.watchStudentClassRolls(
      tenantId: _resolveTenantId(),
      studentId: studentId,
      academicSession: academicSession,
    );
  }

  Future<void> createOrUpdateStudent({
    required String studentId,
    required String admissionNo,
    required String fullName,
    String? classSection,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.createOrUpdateStudentProfile(
      studentId: studentId,
      tenantId: tenantId,
      admissionNo: admissionNo,
      fullName: fullName,
      classSection: classSection,
      isActive: isActive,
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'student_profile',
      entityId: studentId,
      operation: 'upsert',
      payload: jsonEncode({
        'studentId': studentId,
        'tenantId': tenantId,
        'admissionNo': admissionNo,
        'fullName': fullName,
        'classSection': classSection,
        'isActive': isActive,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> createOrUpdateGuardian({
    String? guardianId,
    required String studentId,
    required String fullName,
    required String relation,
    String? phone,
    String? email,
    bool isPrimary = false,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedGuardianId =
        guardianId ??
        'gr_${tenantId}_${studentId}_${now.millisecondsSinceEpoch}';

    await database.upsertStudentGuardianRecord(
      guardianId: resolvedGuardianId,
      tenantId: tenantId,
      studentId: studentId,
      fullName: fullName,
      relation: relation,
      phone: phone,
      email: email,
      isPrimary: isPrimary,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'student_guardian',
      entityId: resolvedGuardianId,
      operation: 'upsert',
      payload: jsonEncode({
        'guardianId': resolvedGuardianId,
        'tenantId': tenantId,
        'studentId': studentId,
        'fullName': fullName,
        'relation': relation,
        'phone': phone,
        'email': email,
        'isPrimary': isPrimary,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> setGuardianStatus({
    required StudentGuardianEntry guardian,
    required bool isActive,
  }) {
    return createOrUpdateGuardian(
      guardianId: guardian.id,
      studentId: guardian.studentId,
      fullName: guardian.fullName,
      relation: guardian.relation,
      phone: guardian.phone,
      email: guardian.email,
      isPrimary: guardian.isPrimary,
      isActive: isActive,
    );
  }

  Future<void> createOrUpdateEnrollment({
    String? enrollmentId,
    required String studentId,
    required String academicSession,
    required String enrollmentStatus,
    DateTime? enrolledOn,
    DateTime? leftOn,
    String? remarks,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedEnrollmentId =
        enrollmentId ??
        'en_${tenantId}_${studentId}_${academicSession}_${now.millisecondsSinceEpoch}';

    await database.upsertStudentEnrollmentRecord(
      enrollmentId: resolvedEnrollmentId,
      tenantId: tenantId,
      studentId: studentId,
      academicSession: academicSession,
      enrollmentStatus: enrollmentStatus,
      enrolledOn: enrolledOn,
      leftOn: leftOn,
      remarks: remarks,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'student_enrollment',
      entityId: resolvedEnrollmentId,
      operation: 'upsert',
      payload: jsonEncode({
        'enrollmentId': resolvedEnrollmentId,
        'tenantId': tenantId,
        'studentId': studentId,
        'academicSession': academicSession,
        'enrollmentStatus': enrollmentStatus,
        'enrolledOn': enrolledOn?.toUtc().toIso8601String(),
        'leftOn': leftOn?.toUtc().toIso8601String(),
        'remarks': remarks,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> createOrUpdateClassRoll({
    String? classRollId,
    required String studentId,
    required String academicSession,
    required String className,
    String? sectionName,
    String? rollNo,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedClassRollId =
        classRollId ??
        'cr_${tenantId}_${studentId}_${academicSession}_${now.millisecondsSinceEpoch}';

    await database.upsertStudentClassRollRecord(
      classRollId: resolvedClassRollId,
      tenantId: tenantId,
      studentId: studentId,
      academicSession: academicSession,
      className: className,
      sectionName: sectionName,
      rollNo: rollNo,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'student_class_roll',
      entityId: resolvedClassRollId,
      operation: 'upsert',
      payload: jsonEncode({
        'classRollId': resolvedClassRollId,
        'tenantId': tenantId,
        'studentId': studentId,
        'academicSession': academicSession,
        'className': className,
        'sectionName': sectionName,
        'rollNo': rollNo,
        'isActive': isActive,
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
