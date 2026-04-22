import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _ConflictGateway extends PocketbaseGateway {
  _ConflictGateway({
    this.examScheduleRecords = const [],
    this.examMarkRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> examScheduleRecords;
  final List<Map<String, dynamic>> examMarkRecords;

  int pushedExamScheduleCount = 0;
  final List<String> pushedExamNames = <String>[];

  @override
  Future<bool> pushExamSchedule({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    pushedExamScheduleCount++;
    final name =
        (payload['examName'] ?? payload['exam_name'])?.toString() ?? '';
    pushedExamNames.add(name);
    return true;
  }

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
  group('Sync conflict resolution (timestamp policy)', () {
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
      'pull upsert skips stale remote exam schedule when local is newer',
      () async {
        final localUpdatedAt = DateTime.utc(2026, 5, 3, 8);
        await database.upsertExamScheduleRecord(
          scheduleId: 'sch_1',
          tenantId: tenantId,
          examName: 'Local Latest Name',
          subjectName: 'Math',
          maxMarks: 100,
          examDate: DateTime.utc(2026, 5, 12),
          source: 'local',
          updatedAt: localUpdatedAt,
        );

        final gateway = _ConflictGateway(
          examScheduleRecords: [
            {
              'schedule_id': 'sch_1',
              'tenant_id': tenantId,
              'exam_name': 'Remote Older Name',
              'subject_name': 'Math',
              'max_marks': 90,
              'exam_date': DateTime.utc(2026, 5, 12).toIso8601String(),
              'updated_at': DateTime.utc(2026, 5, 2, 8).toIso8601String(),
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
            .watchExamSchedulesInMonth(
              tenantId: tenantId,
              from: DateTime.utc(2026, 5, 1),
              to: DateTime.utc(2026, 5, 31, 23, 59, 59),
            )
            .first;

        expect(rows.single.examName, 'Local Latest Name');
        expect(rows.single.maxMarks, 100);
      },
    );

    test(
      'pull delete tombstone is ignored when local record is newer',
      () async {
        final localUpdatedAt = DateTime.utc(2026, 5, 3, 8);
        await database.upsertExamScheduleRecord(
          scheduleId: 'sch_2',
          tenantId: tenantId,
          examName: 'Mid Term',
          subjectName: 'Science',
          maxMarks: 100,
          examDate: DateTime.utc(2026, 5, 20),
          source: 'local',
          updatedAt: localUpdatedAt,
        );
        await database.upsertStudentExamMarkRecord(
          markId: 'mark_sch_2_stu_1',
          tenantId: tenantId,
          studentId: 'stu_1',
          scheduleId: 'sch_2',
          marksObtained: 78,
          grade: 'B+',
          source: 'local',
          updatedAt: localUpdatedAt,
        );

        final gateway = _ConflictGateway(
          examScheduleRecords: [
            {
              'schedule_id': 'sch_2',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 5, 2, 8).toIso8601String(),
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
              from: DateTime.utc(2026, 5, 1),
              to: DateTime.utc(2026, 5, 31, 23, 59, 59),
            )
            .first;
        expect(schedules.length, 1);

        final marks = await database
            .watchStudentExamMarkViews(
              tenantId: tenantId,
              studentId: 'stu_1',
              from: DateTime.utc(2026, 5, 1),
              to: DateTime.utc(2026, 5, 31, 23, 59, 59),
            )
            .first;
        expect(marks.length, 1);
      },
    );

    test(
      'push skips stale queued upsert and sends only latest payload',
      () async {
        final olderUpdatedAt = DateTime.utc(2026, 5, 1, 8);
        final latestUpdatedAt = DateTime.utc(2026, 5, 1, 9);

        await database.upsertExamScheduleRecord(
          scheduleId: 'sch_3',
          tenantId: tenantId,
          examName: 'Latest Name',
          subjectName: 'English',
          maxMarks: 100,
          examDate: DateTime.utc(2026, 5, 15),
          source: 'local',
          updatedAt: latestUpdatedAt,
        );

        await database.queueOperation(
          tenantId: tenantId,
          entityType: 'exam_schedule',
          entityId: 'sch_3',
          operation: 'upsert',
          payload: jsonEncode({
            'scheduleId': 'sch_3',
            'tenantId': tenantId,
            'examName': 'Old Name',
            'subjectName': 'English',
            'maxMarks': 100,
            'examDate': DateTime.utc(2026, 5, 15).toIso8601String(),
            'updatedAt': olderUpdatedAt.toIso8601String(),
          }),
        );

        await database.queueOperation(
          tenantId: tenantId,
          entityType: 'exam_schedule',
          entityId: 'sch_3',
          operation: 'upsert',
          payload: jsonEncode({
            'scheduleId': 'sch_3',
            'tenantId': tenantId,
            'examName': 'Latest Name',
            'subjectName': 'English',
            'maxMarks': 100,
            'examDate': DateTime.utc(2026, 5, 15).toIso8601String(),
            'updatedAt': latestUpdatedAt.toIso8601String(),
          }),
        );

        final gateway = _ConflictGateway();
        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        expect(gateway.pushedExamScheduleCount, 1);
        expect(gateway.pushedExamNames.single, 'Latest Name');
        expect(await database.pendingSyncCount(), 0);
      },
    );
  });
}
