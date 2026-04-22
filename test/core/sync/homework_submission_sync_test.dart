import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _SubmissionGateway extends PocketbaseGateway {
  _SubmissionGateway({this.submissionRecords = const []})
    : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> submissionRecords;

  @override
  Future<List<Map<String, dynamic>>> pullTenantLicenses({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullTenantUsageMetrics({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullTenantFeatureFlags({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullNoticeBoards({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullTimetableSlots({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullTransportRoutes({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullHomeworkAssignments({DateTime? since, String? tenantId}) async => const [];
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
  Future<List<Map<String, dynamic>>> pullHomeworkSubmissions({DateTime? since, String? tenantId}) async => submissionRecords;
  @override
  Future<List<Map<String, dynamic>>> pullOnlineLearningItems({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullOnlineLearningAttempts({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLessons({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLessonPlans({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullSubjects({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullSyllabusItems({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLibraryItems({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullDocumentCenterItems({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullVisitorCommunicationEntries({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullNotifications({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLiveClasses({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullSchoolOwners({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentProfiles({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentGuardians({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentEnrollments({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentClassRolls({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentAttendance({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullLeaveRequests({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullPendingTasks({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullHostelRooms({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullFeeInvoices({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullFeePayments({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullExamSchedules({DateTime? since, String? tenantId}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> pullStudentExamMarks({DateTime? since, String? tenantId}) async => const [];
}

void main() {
  group('Homework submission sync', () {
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
      'pull sync ingests submissions, applies tombstones, and updates checkpoint',
      () async {
        // Pre-seed a submission to be deleted
        await database.upsertHomeworkSubmissionRecord(
          submissionId: 'sub_old',
          tenantId: tenantId,
          assignmentId: 'hw_1',
          studentId: 'student_1',
          statusLabel: 'submitted',
          updatedAt: DateTime.utc(2026, 8, 1, 8),
        );

        final gateway = _SubmissionGateway(
          submissionRecords: [
            {
              'submission_id': 'sub_1',
              'tenant_id': tenantId,
              'assignment_id': 'hw_1',
              'student_id': 'student_2',
              'submission_text': 'My answer here',
              'status_label': 'submitted',
              'is_active': true,
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 8, 2, 8).toIso8601String(),
            },
            // Cross-tenant record — should be ignored
            {
              'submission_id': 'sub_other',
              'tenant_id': 'tenant_other',
              'assignment_id': 'hw_x',
              'student_id': 'student_x',
              'status_label': 'submitted',
              'updated_at': DateTime.utc(2026, 8, 2, 9).toIso8601String(),
            },
            // Tombstone for old submission
            {
              'submission_id': 'sub_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 8, 2, 10).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final rows = await database
            .watchHomeworkSubmissions(tenantId: tenantId, assignmentId: 'hw_1')
            .first;
        expect(rows.length, 1);
        expect(rows.single.id, 'sub_1');
        expect(rows.single.submissionText, 'My answer here');

        // Tombstoned record should be gone
        final deleted = await database.getEntityUpdatedAt(
          entityType: 'homework_submission',
          tenantId: tenantId,
          entityId: 'sub_old',
        );
        expect(deleted, isNull);

        // Cross-tenant record should not be ingested
        final crossTenant = await database.getEntityUpdatedAt(
          entityType: 'homework_submission',
          tenantId: 'tenant_other',
          entityId: 'sub_other',
        );
        expect(crossTenant, isNull);

        // Checkpoint should be set
        final checkpoint = await database.getLastPullCheckpoint(
          'homework_submission',
        );
        expect(checkpoint, isNotNull);
      },
    );
  });
}
