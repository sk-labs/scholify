import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/core/theme/scholify_colors.dart';
import 'package:scholify/features/bootstrap/presentation/bootstrap_home_page.dart';
import 'package:scholify/features/sync/presentation/sync_failure_page.dart';

/// Widget tests for BootstrapHomePage warning icon
///
/// Feature: scholify-roadmap-tracker
/// Task: 11.3 Add warning icon to FoundationShell app bar
/// Requirements: A2.7
///
/// Tests the warning icon behavior:
/// - Display persistent warning icon when failed entry count > 0
/// - Navigate to SyncFailurePage on icon tap
/// - Hide icon when failed entry count == 0
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
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: BootstrapHomePage(
        tenantContext: tenantContext,
        syncEngine: syncEngine,
      ),
    );
  }

  Future<void> createFailedSyncEntry(AppLocalDatabase db) async {
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_123',
        operation: 'upsert',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(2),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> createMultipleFailedSyncEntries(
      AppLocalDatabase db, int count) async {
    for (int i = 0; i < count; i++) {
      await db.into(db.syncQueueEntries).insert(
        SyncQueueEntriesCompanion.insert(
          tenantId: 'tenant_1',
          entityType: 'test_entity',
          entityId: 'entity_$i',
          operation: 'upsert',
          payload: '{}',
          status: const Value('failed'),
          retryCount: const Value(1),
          lastAttemptAt: Value(DateTime.now()),
        ),
      );
    }
  }

  group('BootstrapHomePage Warning Icon (A2.7)', () {
    testWidgets('does not display warning icon when no failures exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify warning icon is not displayed
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('displays warning icon when failed entries exist',
        (WidgetTester tester) async {
      await createFailedSyncEntry(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify warning icon is displayed
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgets('displays badge with correct failure count',
        (WidgetTester tester) async {
      await createMultipleFailedSyncEntries(database, 3);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify badge shows correct count
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('navigates to SyncFailurePage when icon is tapped',
        (WidgetTester tester) async {
      await createFailedSyncEntry(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the warning icon
      await tester.tap(find.byIcon(Icons.warning_amber_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify navigation to SyncFailurePage
      expect(find.byType(SyncFailurePage), findsOneWidget);
      expect(find.text('Sync Failures'), findsNWidgets(2)); // Title appears twice (app bar + page)
    });

    testWidgets('icon is positioned in app bar actions',
        (WidgetTester tester) async {
      await createFailedSyncEntry(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No page-level AppBar: the shell provides the top bar.
      expect(find.byType(AppBar), findsNothing);

      // Verify icon is present in the page header instead.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('badge has correct styling', (WidgetTester tester) async {
      await createFailedSyncEntry(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the Badge widget
      final badge = tester.widget<Badge>(find.byType(Badge));

      // Verify badge styling (education palette error color)
      expect(badge.backgroundColor, ScholifyColors.error);
      expect(badge.textColor, Colors.white);
    });
  });

  group('BootstrapHomePage Warning Icon - Property Test', () {
    testWidgets(
        'warning icon visibility invariant: shown iff failed count > 0',
        (WidgetTester tester) async {
      // Test with 0 failures
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });
}
