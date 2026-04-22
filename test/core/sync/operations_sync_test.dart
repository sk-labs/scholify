import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _OperationsGateway extends PocketbaseGateway {
  _OperationsGateway({
    this.leaveRecords = const [],
    this.pendingTaskRecords = const [],
    this.hostelRoomRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> leaveRecords;
  final List<Map<String, dynamic>> pendingTaskRecords;
  final List<Map<String, dynamic>> hostelRoomRecords;

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
  Future<List<Map<String, dynamic>>> pullLeaveRequests({
    DateTime? since,
    String? tenantId,
  }) async => leaveRecords;

  @override
  Future<List<Map<String, dynamic>>> pullPendingTasks({
    DateTime? since,
    String? tenantId,
  }) async => pendingTaskRecords;

  @override
  Future<List<Map<String, dynamic>>> pullHostelRooms({
    DateTime? since,
    String? tenantId,
  }) async => hostelRoomRecords;

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
  group('Operations sync', () {
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
      'pull sync ingests operations modules and applies tombstones',
      () async {
        await database.upsertLeaveRequestRecord(
          leaveId: 'leave_old',
          tenantId: tenantId,
          reason: 'Old request',
          updatedAt: DateTime.utc(2026, 1, 1, 8),
        );
        await database.upsertPendingTaskRecord(
          taskId: 'task_old',
          tenantId: tenantId,
          title: 'Old task',
          updatedAt: DateTime.utc(2026, 1, 1, 8),
        );
        await database.upsertHostelRoomRecord(
          roomId: 'room_old',
          tenantId: tenantId,
          hostelName: 'Old Hostel',
          roomNo: '01',
          updatedAt: DateTime.utc(2026, 1, 1, 8),
        );

        final gateway = _OperationsGateway(
          leaveRecords: [
            {
              'leave_id': 'leave_1',
              'tenant_id': tenantId,
              'requester_id': 'student_1',
              'leave_from': DateTime.utc(2026, 2, 1).toIso8601String(),
              'leave_to': DateTime.utc(2026, 2, 3).toIso8601String(),
              'applied_at': DateTime.utc(2026, 2, 1, 9).toIso8601String(),
              'reason': 'Family event',
              'status_label': 'approved',
              'approved_at': DateTime.utc(2026, 2, 1, 10).toIso8601String(),
              'is_active': true,
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 2, 2, 8).toIso8601String(),
            },
            {
              'leave_id': 'leave_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 2, 2, 9).toIso8601String(),
            },
          ],
          pendingTaskRecords: [
            {
              'task_id': 'task_1',
              'tenant_id': tenantId,
              'title': 'Prepare exam schedule',
              'due_date': DateTime.utc(2026, 2, 5).toIso8601String(),
              'status_label': 'pending',
              'is_completed': false,
              'priority': 'high',
              'is_active': true,
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 2, 2, 8).toIso8601String(),
            },
            {
              'task_id': 'task_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 2, 2, 9).toIso8601String(),
            },
          ],
          hostelRoomRecords: [
            {
              'room_id': 'room_1',
              'tenant_id': tenantId,
              'student_id': 'student_1',
              'hostel_name': 'North Hall',
              'room_no': 'A-12',
              'room_type': 'single',
              'floor_no': '1',
              'bed_no': '1',
              'warden_name': 'Mr. Khan',
              'warden_contact': '1234567890',
              'monthly_fees': 1350,
              'is_active': true,
              'source': 'remote',
              'updated_at': DateTime.utc(2026, 2, 2, 8).toIso8601String(),
            },
            {
              'room_id': 'room_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 2, 2, 9).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final leaves = await database
            .watchLeaveRequests(tenantId: tenantId)
            .first;
        expect(leaves, hasLength(1));
        expect(leaves.single.id, 'leave_1');

        final tasks = await database
            .watchPendingTasks(tenantId: tenantId)
            .first;
        expect(tasks, hasLength(1));
        expect(tasks.single.id, 'task_1');

        final rooms = await database.watchHostelRooms(tenantId: tenantId).first;
        expect(rooms, hasLength(1));
        expect(rooms.single.id, 'room_1');

        expect(
          await database.getEntityUpdatedAt(
            entityType: 'leave_request',
            tenantId: tenantId,
            entityId: 'leave_old',
          ),
          isNull,
        );
        expect(
          await database.getEntityUpdatedAt(
            entityType: 'pending_task',
            tenantId: tenantId,
            entityId: 'task_old',
          ),
          isNull,
        );
        expect(
          await database.getEntityUpdatedAt(
            entityType: 'hostel_room',
            tenantId: tenantId,
            entityId: 'room_old',
          ),
          isNull,
        );

        expect(
          await database.getLastPullCheckpoint('leave_request'),
          isNotNull,
        );
        expect(await database.getLastPullCheckpoint('pending_task'), isNotNull);
        expect(await database.getLastPullCheckpoint('hostel_room'), isNotNull);
      },
    );
  });
}
