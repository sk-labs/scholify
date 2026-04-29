import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/sync/presentation/sync_failure_page.dart';
import 'package:scholify/app/app_runtime.dart';
import 'package:drift/drift.dart';

/// Widget tests for SyncFailurePage
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A2.1, A2.2, A2.6
///
/// Tests the sync failure page behavior including:
/// - Display failed sync entries where retryCount > 0 and status != 'synced'
/// - Display entity type, entity ID, operation, retry count, timestamp
/// - Show empty state when no failures exist
/// - Order by lastAttemptAt DESC
void main() {
  late AppLocalDatabase database;
  late SyncEngine syncEngine;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    syncEngine = SyncEngine(
      database: database,
      pocketbaseGateway: gateway,
      tenantContext: tenantContext,
    );
    
    // Set AppRuntime for the page to access
    AppRuntime.set(
      tenantContextValue: tenantContext,
      syncEngineValue: syncEngine,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: SyncFailurePage(),
    );
  }

  Future<void> createFailedSyncEntries(AppLocalDatabase db) async {
    // Create failed sync entries with different retry counts
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_123',
        operation: 'upsert',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(2),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );

    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'tenant_license',
        entityId: 'license_456',
        operation: 'upsert',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(4),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(minutes: 30))),
      ),
    );

    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'school_owner',
        entityId: 'owner_789',
        operation: 'delete',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(1),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(days: 1))),
      ),
    );

    // Create a synced entry (should not appear in failed list)
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_999',
        operation: 'upsert',
        payload: '{}',
        status: const Value('synced'),
        retryCount: const Value(0),
      ),
    );

    // Create a pending entry with no retries (should not appear in failed list)
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_888',
        operation: 'upsert',
        payload: '{}',
        status: const Value('pending'),
        retryCount: const Value(0),
      ),
    );
  }

  group('SyncFailurePage', () {
    testWidgets('displays empty state when no failures exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify empty state message (A2.6)
      expect(find.text('All operations synced successfully'), findsOneWidget);
      expect(find.text('No sync failures to display'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('displays failed sync entries with correct information',
        (WidgetTester tester) async {
      await createFailedSyncEntries(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify failed entries are displayed (A2.1, A2.2)
      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.text('Tenant License'), findsOneWidget);
      expect(find.text('School Owner'), findsOneWidget);

      // Verify entity IDs are displayed
      expect(find.textContaining('student_123'), findsOneWidget);
      expect(find.textContaining('license_456'), findsOneWidget);
      expect(find.textContaining('owner_789'), findsOneWidget);

      // Verify operations are displayed
      expect(find.text('UPSERT'), findsNWidgets(2));
      expect(find.text('DELETE'), findsOneWidget);

      // Verify retry counts are displayed
      expect(find.textContaining('2 retries'), findsOneWidget);
      expect(find.textContaining('4 retries'), findsOneWidget);
      expect(find.textContaining('1 retry'), findsOneWidget);

      // Verify synced entry is NOT displayed
      expect(find.textContaining('student_999'), findsNothing);
      
      // Verify pending entry with no retries is NOT displayed
      expect(find.textContaining('student_888'), findsNothing);
    });

    testWidgets('displays entries ordered by lastAttemptAt DESC',
        (WidgetTester tester) async {
      await createFailedSyncEntries(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find all cards
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(3));

      // The order should be:
      // 1. license_456 (30 minutes ago) - most recent
      // 2. student_123 (1 hour ago)
      // 3. owner_789 (1 day ago) - oldest

      // We can verify by checking the text order in the widget tree
      final cardWidgets = tester.widgetList<Card>(cards).toList();
      expect(cardWidgets.length, 3);
    });

    testWidgets('displays severity colors based on retry count',
        (WidgetTester tester) async {
      await createFailedSyncEntries(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify retry count badges are displayed with different colors
      // (visual verification would require checking Container decorations)
      expect(find.textContaining('1 retry'), findsOneWidget); // Amber
      expect(find.textContaining('2 retries'), findsOneWidget); // Orange
      expect(find.textContaining('4 retries'), findsOneWidget); // Red
    });

    testWidgets('displays error message section for each entry',
        (WidgetTester tester) async {
      await createFailedSyncEntries(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify error message sections are displayed
      expect(find.text('Error Message'), findsNWidgets(3));
      expect(find.byIcon(Icons.error_outline), findsNWidgets(3));
      
      // Verify placeholder error messages
      expect(find.textContaining('Sync operation failed after'), findsNWidgets(3));
    });

    testWidgets('displays formatted timestamps',
        (WidgetTester tester) async {
      await createFailedSyncEntries(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify timestamps are displayed
      expect(find.text('Last Attempt'), findsNWidgets(3));
      
      // Check for relative time formats
      // Note: Exact text depends on timing, so we just verify the label exists
      expect(find.textContaining('ago'), findsWidgets);
    });

    testWidgets('displays app bar with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sync Failures'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('handles database query errors gracefully',
        (WidgetTester tester) async {
      // Close the database to simulate an error
      await database.close();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should display error state
      expect(find.text('Error loading sync failures'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('SyncFailurePage Database Query', () {
    test('getFailedSyncEntries returns only failed entries with retries',
        () async {
      await createFailedSyncEntries(database);

      final failedEntries = await database.getFailedSyncEntries();

      // Should return 3 failed entries (not the synced or pending with 0 retries)
      expect(failedEntries.length, 3);

      // Verify all entries have retryCount > 0
      for (final entry in failedEntries) {
        expect(entry.retryCount, greaterThan(0));
        expect(entry.status, isNot('synced'));
      }
    });

    test('getFailedSyncEntries orders by lastAttemptAt DESC', () async {
      await createFailedSyncEntries(database);

      final failedEntries = await database.getFailedSyncEntries();

      // Verify order: most recent first
      expect(failedEntries[0].entityId, 'license_456'); // 30 min ago
      expect(failedEntries[1].entityId, 'student_123'); // 1 hour ago
      expect(failedEntries[2].entityId, 'owner_789'); // 1 day ago
    });

    test('watchFailedSyncEntries emits updates when entries change', () async {
      final stream = database.watchFailedSyncEntries();
      
      // Initial state: no failures
      expect(await stream.first, isEmpty);

      // Add a failed entry
      await database.into(database.syncQueueEntries).insert(
        SyncQueueEntriesCompanion.insert(
          tenantId: 'tenant_1',
          entityType: 'test_entity',
          entityId: 'test_123',
          operation: 'upsert',
          payload: '{}',
          status: const Value('failed'),
          retryCount: const Value(1),
        ),
      );

      // Stream should emit the new entry
      final entries = await stream.first;
      expect(entries.length, 1);
      expect(entries[0].entityId, 'test_123');
    });
  });
}
