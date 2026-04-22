import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _CurriculumGateway extends PocketbaseGateway {
  _CurriculumGateway({
    this.lessonRecords = const [],
    this.lessonPlanRecords = const [],
    this.subjectRecords = const [],
    this.syllabusRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> lessonRecords;
  final List<Map<String, dynamic>> lessonPlanRecords;
  final List<Map<String, dynamic>> subjectRecords;
  final List<Map<String, dynamic>> syllabusRecords;

  @override
  Future<List<Map<String, dynamic>>> pullTenantLicenses({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullTenantUsageMetrics({
    DateTime? since,
    String? tenantId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullTenantFeatureFlags({
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
  }) async => lessonRecords;

  @override
  Future<List<Map<String, dynamic>>> pullLessonPlans({
    DateTime? since,
    String? tenantId,
  }) async => lessonPlanRecords;

  @override
  Future<List<Map<String, dynamic>>> pullSubjects({
    DateTime? since,
    String? tenantId,
  }) async => subjectRecords;

  @override
  Future<List<Map<String, dynamic>>> pullSyllabusItems({
    DateTime? since,
    String? tenantId,
  }) async => syllabusRecords;

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
  Future<List<Map<String, dynamic>>> pullSchoolOwners({
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
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pullStudentClassRolls({
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
  group('Curriculum sync', () {
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
      'pull sync ingests curriculum entities, applies tombstones, and updates checkpoints',
      () async {
        await database.upsertLessonRecord(
          lessonId: 'lesson_old',
          tenantId: tenantId,
          title: 'Old Lesson',
          source: 'local',
          updatedAt: DateTime.utc(2026, 9, 1, 8),
        );

        final gateway = _CurriculumGateway(
          lessonRecords: [
            {
              'lesson_id': 'lesson_1',
              'tenant_id': tenantId,
              'title': 'Matter and Materials',
              'class_section': '7-A',
              'subject_name': 'Science',
              'updated_at': DateTime.utc(2026, 9, 2, 8).toIso8601String(),
            },
            {
              'lesson_id': 'lesson_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 9, 2, 10).toIso8601String(),
            },
          ],
          lessonPlanRecords: [
            {
              'plan_id': 'plan_1',
              'tenant_id': tenantId,
              'title': 'Science Week Plan',
              'objective': 'Hands-on learning',
              'updated_at': DateTime.utc(2026, 9, 2, 9).toIso8601String(),
            },
          ],
          subjectRecords: [
            {
              'subject_id': 'subject_1',
              'tenant_id': tenantId,
              'subject_name': 'Science',
              'subject_code': 'SCI-07',
              'updated_at': DateTime.utc(2026, 9, 2, 9, 30).toIso8601String(),
            },
          ],
          syllabusRecords: [
            {
              'syllabus_id': 'syllabus_1',
              'tenant_id': tenantId,
              'title': 'Term 1 Science Syllabus',
              'status_label': 'in_progress',
              'completion_percent': '45%',
              'updated_at': DateTime.utc(2026, 9, 2, 10, 30).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final lessons = await database.watchLessons(tenantId: tenantId).first;
        final plans = await database.watchLessonPlans(tenantId: tenantId).first;
        final subjects = await database.watchSubjects(tenantId: tenantId).first;
        final syllabus = await database
            .watchSyllabusItems(tenantId: tenantId)
            .first;

        expect(lessons.length, 1);
        expect(lessons.single.id, 'lesson_1');
        expect(plans.length, 1);
        expect(subjects.length, 1);
        expect(syllabus.length, 1);

        expect(
          await database.getEntityUpdatedAt(
            entityType: 'lesson',
            tenantId: tenantId,
            entityId: 'lesson_old',
          ),
          isNull,
        );

        expect(await database.getLastPullCheckpoint('lesson'), isNotNull);
        expect(await database.getLastPullCheckpoint('lesson_plan'), isNotNull);
        expect(await database.getLastPullCheckpoint('subject'), isNotNull);
        expect(await database.getLastPullCheckpoint('syllabus'), isNotNull);
      },
    );
  });
}
