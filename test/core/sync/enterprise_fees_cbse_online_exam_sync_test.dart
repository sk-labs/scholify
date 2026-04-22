import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _EnterpriseSyncGateway extends PocketbaseGateway {
  _EnterpriseSyncGateway({
    this.feeGroupRecords = const [],
    this.cbseResultRecords = const [],
    this.onlineExamRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> feeGroupRecords;
  final List<Map<String, dynamic>> cbseResultRecords;
  final List<Map<String, dynamic>> onlineExamRecords;

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
  @override Future<List<Map<String, dynamic>>> pullFeeGroups({DateTime? since, String? tenantId}) async => feeGroupRecords;
  @override Future<List<Map<String, dynamic>>> pullCbseExamResults({DateTime? since, String? tenantId}) async => cbseResultRecords;
  @override Future<List<Map<String, dynamic>>> pullOnlineExams({DateTime? since, String? tenantId}) async => onlineExamRecords;
  @override Future<List<Map<String, dynamic>>> pullStudentBehaviour({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullBehaviourComments({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullTeachers({DateTime? since, String? tenantId}) async => const [];
  @override Future<List<Map<String, dynamic>>> pullOnlineLessons({DateTime? since, String? tenantId}) async => const [];
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
  group('Enterprise fees / CBSE results / Online exam sync', () {
    const tenantId = 'tenant_alpha';
    const studentId = 'tenant_alpha'; // matches _studentId() fallback

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

    test('pull sync ingests fee groups, applies tombstones, and checkpoints', () async {
      // Pre-seed a fee group to be deleted
      await database.upsertFeeGroupRecord(
        feeId: 'fg_old',
        tenantId: tenantId,
        studentId: studentId,
        feeTitle: 'Old Fee',
        updatedAt: DateTime.utc(2026, 9, 1, 8),
      );

      final gateway = _EnterpriseSyncGateway(
        feeGroupRecords: [
          {
            'fee_id': 'fg_1',
            'tenant_id': tenantId,
            'student_id': studentId,
            'fee_title': 'Tuition Fee',
            'fee_code': 'TF-2026',
            'amount': 5000.0,
            'discount': 200.0,
            'fine': 50.0,
            'paid': 2000.0,
            'balance': 2850.0,
            'status': 'partial',
            'due_date': '2026-09-30',
            'is_payable': true,
            'fee_type': 'fee',
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 9, 2, 8).toIso8601String(),
          },
          // Cross-tenant — should be ignored
          {
            'fee_id': 'fg_other',
            'tenant_id': 'tenant_other',
            'student_id': 'student_x',
            'fee_title': 'Other Fee',
            'updated_at': DateTime.utc(2026, 9, 2, 9).toIso8601String(),
          },
          // Tombstone
          {
            'fee_id': 'fg_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 9, 2, 10).toIso8601String(),
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
          .watchFeeGroups(tenantId: tenantId, studentId: studentId)
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'fg_1');
      expect(rows.single.feeTitle, 'Tuition Fee');
      expect(rows.single.balance, 2850.0);

      // Tombstoned record gone
      expect(
        await database.getEntityUpdatedAt(
          entityType: 'fee_group',
          tenantId: tenantId,
          entityId: 'fg_old',
        ),
        isNull,
      );

      // Cross-tenant not ingested
      expect(
        await database.getEntityUpdatedAt(
          entityType: 'fee_group',
          tenantId: 'tenant_other',
          entityId: 'fg_other',
        ),
        isNull,
      );

      expect(await database.getLastPullCheckpoint('fee_group'), isNotNull);
    });

    test('pull sync ingests CBSE exam results and applies tombstones', () async {
      await database.upsertCbseExamResultRecord(
        resultId: 'cbse_old',
        tenantId: tenantId,
        studentId: studentId,
        examName: 'Old Exam',
        subjectName: 'Old Subject',
        updatedAt: DateTime.utc(2026, 9, 1, 8),
      );

      final gateway = _EnterpriseSyncGateway(
        cbseResultRecords: [
          {
            'result_id': 'cbse_1',
            'tenant_id': tenantId,
            'student_id': studentId,
            'exam_name': 'Annual Exam 2026',
            'subject_name': 'Mathematics',
            'subject_code': 'MATH-10',
            'assessment_name': 'Theory',
            'marks_obtained': 85.0,
            'max_marks': 100.0,
            'grade': 'A',
            'rank': '3',
            'percentage': '85.00',
            'result_type': 'result',
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 9, 2, 8).toIso8601String(),
          },
          {
            'result_id': 'cbse_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 9, 2, 9).toIso8601String(),
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
          .watchCbseExamResults(
            tenantId: tenantId,
            studentId: studentId,
          )
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'cbse_1');
      expect(rows.single.subjectName, 'Mathematics');
      expect(rows.single.marksObtained, 85.0);

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'cbse_exam_result',
          tenantId: tenantId,
          entityId: 'cbse_old',
        ),
        isNull,
      );

      expect(await database.getLastPullCheckpoint('cbse_exam_result'), isNotNull);
    });

    test('pull sync ingests online exams, applies tombstones, and checkpoints', () async {
      await database.upsertOnlineExamRecord(
        examId: 'oex_old',
        tenantId: tenantId,
        examTitle: 'Old Exam',
        updatedAt: DateTime.utc(2026, 9, 1, 8),
      );

      final gateway = _EnterpriseSyncGateway(
        onlineExamRecords: [
          {
            'exam_id': 'oex_1',
            'tenant_id': tenantId,
            'exam_title': 'Science Quiz',
            'exam_from': '2026-09-10 09:00:00',
            'exam_to': '2026-09-10 10:00:00',
            'total_question': 20,
            'total_attempt': 2,
            'duration': 60,
            'passing_percentage': 40.0,
            'is_quiz': true,
            'status': 'upcoming',
            'is_active': true,
            'source': 'remote',
            'updated_at': DateTime.utc(2026, 9, 2, 8).toIso8601String(),
          },
          {
            'exam_id': 'oex_old',
            'tenant_id': tenantId,
            'operation': 'delete',
            'updated_at': DateTime.utc(2026, 9, 2, 9).toIso8601String(),
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
          .watchOnlineExams(tenantId: tenantId)
          .first;
      expect(rows.length, 1);
      expect(rows.single.id, 'oex_1');
      expect(rows.single.examTitle, 'Science Quiz');
      expect(rows.single.isQuiz, true);
      expect(rows.single.totalAttempt, 2);

      expect(
        await database.getEntityUpdatedAt(
          entityType: 'online_exam',
          tenantId: tenantId,
          entityId: 'oex_old',
        ),
        isNull,
      );

      expect(await database.getLastPullCheckpoint('online_exam'), isNotNull);
    });
  });
}
