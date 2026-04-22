import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _VisitorNotificationGateway extends PocketbaseGateway {
  _VisitorNotificationGateway({
    this.visitorRecords = const [],
    this.notificationRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> visitorRecords;
  final List<Map<String, dynamic>> notificationRecords;

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
  }) async => visitorRecords;

  @override
  Future<List<Map<String, dynamic>>> pullNotifications({
    DateTime? since,
    String? tenantId,
  }) async => notificationRecords;
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
  group('Visitor + notification sync', () {
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
      'pull sync ingests entries, handles tombstones, and updates checkpoints',
      () async {
        await database.upsertVisitorCommunicationRecord(
          entryId: 'visit_old',
          tenantId: tenantId,
          entryType: 'visitor_book',
          purpose: 'Legacy visit',
          updatedAt: DateTime.utc(2026, 10, 1, 8),
        );

        final gateway = _VisitorNotificationGateway(
          visitorRecords: [
            {
              'entry_id': 'visit_1',
              'tenant_id': tenantId,
              'entry_type': 'timeline',
              'purpose': 'Campus update',
              'status_label': 'open',
              'updated_at': DateTime.utc(2026, 10, 2, 8).toIso8601String(),
            },
            {
              'entry_id': 'visit_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 10, 2, 9).toIso8601String(),
            },
          ],
          notificationRecords: [
            {
              'notification_id': 'notif_1',
              'tenant_id': tenantId,
              'notification_type': 'alert',
              'title': 'Emergency Drill',
              'body': 'Assembly point A',
              'delivery_status': 'sent',
              'updated_at': DateTime.utc(2026, 10, 2, 10).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final visitors = await database
            .watchVisitorCommunicationEntries(tenantId: tenantId)
            .first;
        final notifications = await database
            .watchNotifications(tenantId: tenantId)
            .first;

        expect(visitors.length, 1);
        expect(visitors.single.id, 'visit_1');
        expect(notifications.length, 1);
        expect(notifications.single.id, 'notif_1');

        expect(
          await database.getEntityUpdatedAt(
            entityType: 'visitor_communication',
            tenantId: tenantId,
            entityId: 'visit_old',
          ),
          isNull,
        );

        expect(
          await database.getLastPullCheckpoint('visitor_communication'),
          isNotNull,
        );
        expect(await database.getLastPullCheckpoint('notification'), isNotNull);
      },
    );
  });
}
