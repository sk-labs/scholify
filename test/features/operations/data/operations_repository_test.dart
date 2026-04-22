import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/hostel/data/hostel_repository.dart';
import 'package:scholify/features/leave/data/leave_request_repository.dart';
import 'package:scholify/features/pending_tasks/data/pending_task_repository.dart';

void main() {
  group('Operations repositories', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late LeaveRequestRepository leaveRepository;
    late PendingTaskRepository taskRepository;
    late HostelRepository hostelRepository;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
      tenantContext = TenantContext()
        ..setTenant(
          tenantId: tenantId,
          tenantName: 'Alpha School',
          role: 'school_owner',
          isSuperAdmin: false,
        );

      syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: PocketbaseGateway(baseUrl: 'http://127.0.0.1:8090'),
        tenantContext: tenantContext,
      );

      leaveRepository = LeaveRequestRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
      taskRepository = PendingTaskRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
      hostelRepository = HostelRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('leave requests queue save and delete operations', () async {
      await leaveRepository.saveLeaveRequest(
        requesterId: 'student_1',
        leaveFrom: DateTime.utc(2026, 5, 1),
        leaveTo: DateTime.utc(2026, 5, 3),
        reason: 'Medical leave',
      );

      final rows = await database.watchLeaveRequests(tenantId: tenantId).first;
      expect(rows, hasLength(1));

      await leaveRepository.deleteLeaveRequest(rows.single);

      final queue = await database.getSyncQueueDispatchBatch(
        limit: 20,
        tenantId: tenantId,
      );
      final ops = queue
          .where((row) => row.entityType == 'leave_request')
          .toList();

      expect(ops, hasLength(2));
      expect(ops.where((row) => row.operation == 'upsert'), hasLength(1));
      expect(ops.where((row) => row.operation == 'delete'), hasLength(1));
    });

    test('pending tasks queue save and delete operations', () async {
      await taskRepository.saveTask(
        title: 'Prepare lesson plan',
        dueDate: DateTime.utc(2026, 6, 2),
        priority: 'high',
      );

      final rows = await database.watchPendingTasks(tenantId: tenantId).first;
      expect(rows, hasLength(1));

      await taskRepository.deleteTask(rows.single);

      final queue = await database.getSyncQueueDispatchBatch(
        limit: 20,
        tenantId: tenantId,
      );
      final ops = queue
          .where((row) => row.entityType == 'pending_task')
          .toList();

      expect(ops, hasLength(2));
      expect(ops.where((row) => row.operation == 'upsert'), hasLength(1));
      expect(ops.where((row) => row.operation == 'delete'), hasLength(1));
    });

    test('hostel rooms queue save and delete operations', () async {
      await hostelRepository.saveRoom(
        studentId: 'student_2',
        hostelName: 'North Hall',
        roomNo: 'A-12',
        roomType: 'single',
        monthlyFees: 1250,
      );

      final rows = await database.watchHostelRooms(tenantId: tenantId).first;
      expect(rows, hasLength(1));

      await hostelRepository.deleteRoom(rows.single);

      final queue = await database.getSyncQueueDispatchBatch(
        limit: 20,
        tenantId: tenantId,
      );
      final ops = queue
          .where((row) => row.entityType == 'hostel_room')
          .toList();

      expect(ops, hasLength(2));
      expect(ops.where((row) => row.operation == 'upsert'), hasLength(1));
      expect(ops.where((row) => row.operation == 'delete'), hasLength(1));
    });
  });
}
