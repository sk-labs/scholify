import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _FakeStudentSyncGateway extends PocketbaseGateway {
  _FakeStudentSyncGateway({
    this.enrollmentRecords = const [],
    this.classRollRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> enrollmentRecords;
  final List<Map<String, dynamic>> classRollRecords;

  @override
  Future<List<Map<String, dynamic>>> pullTenantLicenses({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullSchoolOwners({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullNoticeBoards({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullTimetableSlots({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullTransportRoutes({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullHomeworkAssignments({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullOnlineLearningItems({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullLessons({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullLessonPlans({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullSubjects({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullSyllabusItems({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullLibraryItems({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullDocumentCenterItems({
    DateTime? since,
    String? tenantId,
  }) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullVisitorCommunicationEntries({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullNotifications({
    DateTime? since,
    String? tenantId,
  }) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLiveClasses({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentProfiles({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentGuardians({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentEnrollments({
    DateTime? since,
    String? tenantId,
  }) async => enrollmentRecords;

  @override
  Future<List<Map<String, dynamic>>> pullStudentClassRolls({
    DateTime? since,
    String? tenantId,
  }) async => classRollRecords;

  @override
  Future<List<Map<String, dynamic>>> pullStudentAttendance({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullFeeInvoices({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullFeePayments({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullExamSchedules({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentBehaviour({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullBehaviourComments({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullTeachers({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullOnlineLessons({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullFeeGroups({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullCbseExamResults({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullOnlineExams({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullHomeworkSubmissions({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullOnlineLearningAttempts({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentExamMarks({
    DateTime? since,
    String? tenantId,
  }) async => const [];
}

void main() {
  group('Student enrollment/class-roll sync', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
      tenantContext = TenantContext()
        ..setTenant(
          tenantId: tenantId,
          tenantName: 'Alpha School',
          role: 'school_owner',
          isSuperAdmin: false,
        );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'pull sync ingests enrollment and class-roll for active tenant only',
      () async {
        final gateway = _FakeStudentSyncGateway(
          enrollmentRecords: [
            {
              'enrollment_id': 'en_1',
              'tenant_id': tenantId,
              'student_id': 'stu_1',
              'academic_session': '2026-2027',
              'enrollment_status': 'enrolled',
              'enrolled_on': DateTime.utc(2026, 4, 1).toIso8601String(),
              'remarks': 'New admission',
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 4, 2, 8).toIso8601String(),
            },
            {
              'enrollment_id': 'en_other',
              'tenant_id': 'tenant_other',
              'student_id': 'stu_9',
              'academic_session': '2026-2027',
              'enrollment_status': 'enrolled',
              'updated_at': DateTime.utc(2026, 4, 2, 9).toIso8601String(),
            },
          ],
          classRollRecords: [
            {
              'class_roll_id': 'cr_1',
              'tenant_id': tenantId,
              'student_id': 'stu_1',
              'academic_session': '2026-2027',
              'class_name': '7',
              'section_name': 'B',
              'roll_no': '17',
              'is_active': true,
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 4, 2, 8, 30).toIso8601String(),
            },
            {
              'class_roll_id': 'cr_other',
              'tenant_id': 'tenant_other',
              'student_id': 'stu_9',
              'academic_session': '2026-2027',
              'class_name': '8',
              'updated_at': DateTime.utc(2026, 4, 2, 9, 30).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final enrollments = await database
            .watchStudentEnrollments(tenantId: tenantId, studentId: 'stu_1')
            .first;
        expect(enrollments.length, 1);
        expect(enrollments.single.id, 'en_1');
        expect(enrollments.single.enrollmentStatus, 'enrolled');
        expect(enrollments.single.remarks, 'New admission');

        final classRolls = await database
            .watchStudentClassRolls(tenantId: tenantId, studentId: 'stu_1')
            .first;
        expect(classRolls.length, 1);
        expect(classRolls.single.id, 'cr_1');
        expect(classRolls.single.className, '7');
        expect(classRolls.single.sectionName, 'B');
        expect(classRolls.single.rollNo, '17');

        final enrollmentCheckpoint = await database.getLastPullCheckpoint(
          'student_enrollment',
        );
        final classRollCheckpoint = await database.getLastPullCheckpoint(
          'student_class_roll',
        );
        expect(enrollmentCheckpoint, isNotNull);
        expect(classRollCheckpoint, isNotNull);
      },
    );
  });
}
