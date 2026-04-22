import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';

class _LibraryDocumentGateway extends PocketbaseGateway {
  _LibraryDocumentGateway({
    this.libraryRecords = const [],
    this.documentRecords = const [],
  }) : super(baseUrl: 'http://127.0.0.1:8090');

  final List<Map<String, dynamic>> libraryRecords;
  final List<Map<String, dynamic>> documentRecords;

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
  }) async => libraryRecords;

  @override
  Future<List<Map<String, dynamic>>> pullDocumentCenterItems({
    DateTime? since,
    String? tenantId,
  }) async => documentRecords;
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
  group('Library + document sync', () {
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
      'pull sync ingests entities, handles tombstones, and updates checkpoints',
      () async {
        await database.upsertLibraryBookRecord(
          bookId: 'book_old',
          tenantId: tenantId,
          bookType: 'issued',
          title: 'Old Book',
          updatedAt: DateTime.utc(2026, 9, 1, 8),
        );

        final gateway = _LibraryDocumentGateway(
          libraryRecords: [
            {
              'book_id': 'book_1',
              'tenant_id': tenantId,
              'book_type': 'top',
              'title': 'Atomic Habits',
              'author_name': 'James Clear',
              'rating_score': 4.8,
              'issue_count': 32,
              'updated_at': DateTime.utc(2026, 9, 2, 8).toIso8601String(),
            },
            {
              'book_id': 'book_old',
              'tenant_id': tenantId,
              'operation': 'delete',
              'updated_at': DateTime.utc(2026, 9, 2, 9).toIso8601String(),
            },
          ],
          documentRecords: [
            {
              'item_id': 'doc_1',
              'tenant_id': tenantId,
              'content_type': 'download_content',
              'title': 'Homework Guidelines',
              'file_url': 'https://example.com/guidelines.pdf',
              'upload_state': 'uploaded',
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

        final books = await database
            .watchLibraryBooks(tenantId: tenantId)
            .first;
        final docs = await database
            .watchDocumentCenterItems(tenantId: tenantId)
            .first;

        expect(books.length, 1);
        expect(books.single.id, 'book_1');
        expect(docs.length, 1);
        expect(docs.single.id, 'doc_1');

        expect(
          await database.getEntityUpdatedAt(
            entityType: 'library_item',
            tenantId: tenantId,
            entityId: 'book_old',
          ),
          isNull,
        );

        expect(await database.getLastPullCheckpoint('library_item'), isNotNull);
        expect(
          await database.getLastPullCheckpoint('document_center_item'),
          isNotNull,
        );
      },
    );
  });
}
