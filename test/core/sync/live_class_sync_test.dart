import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _LiveClassGateway extends PocketbaseGateway {
  _LiveClassGateway({this.liveClassRecords = const []})
    : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> liveClassRecords;

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
  }) async => liveClassRecords;

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
  group('Live class sync', () {
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
      'pull sync ingests live classes, handles tombstones, and checkpoints',
      () async {
        await database.upsertLiveClassRecord(
          classId: 'live_old',
          tenantId: tenantId,
          providerType: 'zoom',
          title: 'Legacy Session',
          updatedAt: DateTime.utc(2026, 11, 1, 8),
        );

        final gateway = _LiveClassGateway(
          liveClassRecords: [
            {
              'class_id': 'live_1',
              'tenant_id': tenantId,
              'provider_type': 'gmeet',
              'title': 'Science Session',
              'join_url': 'https://meet.google.com/abc-defg-hij',
              'updated_at': DateTime.utc(2026, 11, 2, 8).toIso8601String(),
            },
            {
              'class_id': 'live_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 11, 2, 9).toIso8601String(),
            },
          ],
        );

        final syncEngine = SyncEngine(
          database: database,
          pocketbaseGateway: gateway,
          tenantContext: tenantContext,
        );

        await syncEngine.manualSync();

        final classes = await database
            .watchLiveClasses(tenantId: tenantId)
            .first;
        expect(classes.length, 1);
        expect(classes.single.id, 'live_1');

        expect(
          await database.getEntityUpdatedAt(
            entityType: 'live_class',
            tenantId: tenantId,
            entityId: 'live_old',
          ),
          isNull,
        );

        expect(await database.getLastPullCheckpoint('live_class'), isNotNull);
      },
    );
  });
}
