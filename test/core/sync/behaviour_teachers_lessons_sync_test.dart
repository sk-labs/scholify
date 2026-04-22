import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _BehaviourTeachersGateway extends PocketbaseGateway {
  _BehaviourTeachersGateway({
    this.behaviourRecords = const [],
    this.commentRecords = const [],
    this.teacherRecords = const [],
    this.lessonRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> behaviourRecords;
  final List<Map<String, dynamic>> commentRecords;
  final List<Map<String, dynamic>> teacherRecords;
  final List<Map<String, dynamic>> lessonRecords;

  @override Future<List<Map<String, dynamic>>> pullTenantLicenses({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullTenantUsageMetrics({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullTenantFeatureFlags({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullNoticeBoards({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullTimetableSlots({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullTransportRoutes({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullHomeworkAssignments({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullHomeworkSubmissions({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullOnlineLearningItems({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullOnlineLearningAttempts({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullFeeGroups({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullCbseExamResults({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullOnlineExams({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentBehaviour({DateTime? since, String? tenantId}) async => behaviourRecords;
  @override Future<List<Map<String, dynamic>>> pullBehaviourComments({DateTime? since, String? tenantId}) async => commentRecords;
  @override Future<List<Map<String, dynamic>>> pullTeachers({DateTime? since, String? tenantId}) async => teacherRecords;
  @override Future<List<Map<String, dynamic>>> pullOnlineLessons({DateTime? since, String? tenantId}) async => lessonRecords;
  @override Future<List<Map<String, dynamic>>> pullLessons({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullLessonPlans({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullSubjects({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullSyllabusItems({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullLibraryItems({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullDocumentCenterItems({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullVisitorCommunicationEntries({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullNotifications({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullLiveClasses({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullSchoolOwners({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentProfiles({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentGuardians({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentEnrollments({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentClassRolls({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentAttendance({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullLeaveRequests({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullPendingTasks({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullHostelRooms({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullFeeInvoices({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullFeePayments({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullExamSchedules({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullStudentExamMarks({DateTime? since, String? tenantId}) async => const [];
}

void main() {
  group('Behaviour / Teachers / Online Lessons sync', () {
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

    tearDown(() async => database.close());

    test('pull sync ingests behaviour incidents, tombstones, and checkpoints',
        () async {
      await database.upsertStudentBehaviourRecord(
        incidentId: 'inc_old',
        tenantId: tenantId,
        studentId: 'student_1',
        title: 'Old Incident',
        updatedAt: DateTime.utc(2026, 10, 1, 8),
      );

      final gateway = _BehaviourTeachersGateway(
        behaviourRecords: [
          {
            'incident_id': 'inc_1',
            'tenant_id': tenantId,
            'student_id': 'student_1',
            'title': 'Late to class',
            'description': 'Arrived 15 minutes late',
            'point': '-2',
            'is_positive': false,
            'assigned_by': 'Mr. Smith',
            'incident_date': '2026-10-05',
            'comment_count': 0,
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 10, 2, 8).toIso8601String(),
          },
          {
            'incident_id': 'inc_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 10, 2, 9).toIso8601String(),
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
          .watchStudentBehaviour(tenantId: tenantId, studentId: 'student_1')
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'inc_1');
      expect(rows.single.title, 'Late to class');
      expect(rows.single.isPositive, false);

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'student_behaviour',
          tenantId: tenantId,
          entityId: 'inc_old',
        ),
        isNull,
      );
      expect(
        await database.getLastPullCheckpoint('student_behaviour'),
        isNotNull,
      );
    });

    test('pull sync ingests behaviour comments and tombstones', () async {
      await database.upsertBehaviourCommentRecord(
        commentId: 'cmt_old',
        tenantId: tenantId,
        incidentId: 'inc_1',
        commentText: 'Old comment',
        updatedAt: DateTime.utc(2026, 10, 1, 8),
      );

      final gateway = _BehaviourTeachersGateway(
        commentRecords: [
          {
            'comment_id': 'cmt_1',
            'tenant_id': tenantId,
            'incident_id': 'inc_1',
            'comment_text': 'Student apologised',
            'commented_by': 'Mr. Smith',
            'comment_date': '2026-10-05',
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 10, 2, 8).toIso8601String(),
          },
          {
            'comment_id': 'cmt_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 10, 2, 9).toIso8601String(),
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
          .watchBehaviourComments(tenantId: tenantId, incidentId: 'inc_1')
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'cmt_1');
      expect(rows.single.commentText, 'Student apologised');

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'behaviour_comment',
          tenantId: tenantId,
          entityId: 'cmt_old',
        ),
        isNull,
      );
      expect(
        await database.getLastPullCheckpoint('behaviour_comment'),
        isNotNull,
      );
    });

    test('pull sync ingests teachers, tombstones, and checkpoints', () async {
      await database.upsertTeacherRecord(
        teacherId: 'teacher_old',
        tenantId: tenantId,
        fullName: 'Old Teacher',
        updatedAt: DateTime.utc(2026, 10, 1, 8),
      );

      final gateway = _BehaviourTeachersGateway(
        teacherRecords: [
          {
            'teacher_id': 'teacher_1',
            'tenant_id': tenantId,
            'full_name': 'Dr. Jane Doe',
            'employee_no': 'EMP-001',
            'subject_name': 'Mathematics',
            'qualification': 'PhD',
            'email': 'jane@school.edu',
            'phone': '555-1234',
            'is_class_teacher': true,
            'is_active': true,
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 10, 2, 8).toIso8601String(),
          },
          {
            'teacher_id': 'teacher_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 10, 2, 9).toIso8601String(),
          },
        ],
      );

      final syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: gateway,
        tenantContext: tenantContext,
      );
      await syncEngine.manualSync();

      final rows =
          await database.watchTeachers(tenantId: tenantId).first;
      expect(rows.length, 1);
      expect(rows.single.id, 'teacher_1');
      expect(rows.single.fullName, 'Dr. Jane Doe');
      expect(rows.single.isClassTeacher, true);

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'teacher',
          tenantId: tenantId,
          entityId: 'teacher_old',
        ),
        isNull,
      );
      expect(await database.getLastPullCheckpoint('teacher'), isNotNull);
    });

    test('pull sync ingests online lessons, tombstones, and checkpoints',
        () async {
      await database.upsertOnlineLessonRecord(
        lessonId: 'lesson_old',
        tenantId: tenantId,
        itemId: 'course_1',
        title: 'Old Lesson',
        updatedAt: DateTime.utc(2026, 10, 1, 8),
      );

      final gateway = _BehaviourTeachersGateway(
        lessonRecords: [
          {
            'lesson_id': 'lesson_1',
            'tenant_id': tenantId,
            'item_id': 'course_1',
            'title': 'Introduction to Algebra',
            'content_type': 'video',
            'content_url': 'https://example.com/video1.mp4',
            'sort_order': 1,
            'duration_seconds': 1800,
            'is_completed': false,
            'is_active': true,
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 10, 2, 8).toIso8601String(),
          },
          {
            'lesson_id': 'lesson_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 10, 2, 9).toIso8601String(),
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
          .watchCourseLessons(tenantId: tenantId, itemId: 'course_1')
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'lesson_1');
      expect(rows.single.title, 'Introduction to Algebra');
      expect(rows.single.durationSeconds, 1800);

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'online_lesson',
          tenantId: tenantId,
          entityId: 'lesson_old',
        ),
        isNull,
      );
      expect(
        await database.getLastPullCheckpoint('online_lesson'),
        isNotNull,
      );
    });
  });
}
