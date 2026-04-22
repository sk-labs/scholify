import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _FakePullGateway extends PocketbaseGateway {
  _FakePullGateway({
    this.examScheduleRecords = const [],
    this.examMarkRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> examScheduleRecords;
  final List<Map<String, dynamic>> examMarkRecords;

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
  }) async => examScheduleRecords;

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
  }) async => examMarkRecords;
}

void main() {
  group('Exam tombstone sync', () {
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

    Future<void> seedScheduleWithMark() async {
      final updatedAt = DateTime.utc(2026, 4, 1, 8);
      await database.upsertExamScheduleRecord(
        scheduleId: 'sch_1',
        tenantId: tenantId,
        examName: 'Monthly Test',
        subjectName: 'Math',
        maxMarks: 100,
        examDate: DateTime.utc(2026, 4, 10),
        source: 'local',
        updatedAt: updatedAt,
      );

      await database.upsertStudentExamMarkRecord(
        markId: 'mark_sch_1_stu_1',
        tenantId: tenantId,
        studentId: 'stu_1',
        scheduleId: 'sch_1',
        marksObtained: 78,
        grade: 'B+',
        source: 'local',
        updatedAt: updatedAt,
      );
    }

    test(
      'schedule delete tombstone removes schedule and linked marks',
      () async {
        await seedScheduleWithMark();

        final gateway = _FakePullGateway(
          examScheduleRecords: [
            {
              'schedule_id': 'sch_1',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 4, 2, 9).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final schedules = await database
            .watchExamSchedulesInMonth(
              tenantId: tenantId,
              from: DateTime.utc(2026, 4, 1),
              to: DateTime.utc(2026, 4, 30, 23, 59, 59),
            )
            .first;
        expect(schedules, isEmpty);

        final marks = await database
            .watchStudentExamMarkViews(
              tenantId: tenantId,
              studentId: 'stu_1',
              from: DateTime.utc(2026, 4, 1),
              to: DateTime.utc(2026, 4, 30, 23, 59, 59),
            )
            .first;
        expect(marks, isEmpty);

        final checkpoint = await database.getLastPullCheckpoint(
          'exam_schedule',
        );
        expect(checkpoint, isNotNull);
      },
    );

    test(
      'mark delete tombstone removes mark without deleting schedule',
      () async {
        await seedScheduleWithMark();

        final gateway = _FakePullGateway(
          examMarkRecords: [
            {
              'mark_id': 'mark_sch_1_stu_1',
              'tenant_id': tenantId,
              'student_id': 'stu_1',
              'schedule_id': 'sch_1',
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 4, 2, 10).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final schedules = await database
            .watchExamSchedulesInMonth(
              tenantId: tenantId,
              from: DateTime.utc(2026, 4, 1),
              to: DateTime.utc(2026, 4, 30, 23, 59, 59),
            )
            .first;
        expect(schedules.length, 1);

        final marks = await database
            .watchStudentExamMarkViews(
              tenantId: tenantId,
              studentId: 'stu_1',
              from: DateTime.utc(2026, 4, 1),
              to: DateTime.utc(2026, 4, 30, 23, 59, 59),
            )
            .first;
        expect(marks, isEmpty);

        final checkpoint = await database.getLastPullCheckpoint('exam_mark');
        expect(checkpoint, isNotNull);
      },
    );
  });
}
