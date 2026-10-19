import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/superadmin/presentation/tenant_licensing_page.dart';

/// Widget tests for TenantLicensingPage search functionality
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H2.1, H2.3
///
/// Tests the search field behavior including:
/// - Case-insensitive substring matching
/// - Debouncing (300ms)
/// - Reactive list updates
void main() {
  late AppLocalDatabase database;
  late SyncEngine syncEngine;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  bool dbClosed = false;

  Future<void> closeDbOnce(WidgetTester tester) async {
    if (!dbClosed) {
      dbClosed = true;
      await database.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() {
    dbClosed = false;
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
    if (!dbClosed) {
      dbClosed = true;
      try { await database.close(); } catch (_) {}
    }
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: TenantLicensingPage(
        tenantContext: tenantContext,
        syncEngine: syncEngine,
      ),
    );
  }

  Future<void> createTestTenants(AppLocalDatabase db) async {
    // Create test tenants with different names
    await db.createOrUpdateTenantLicense(
      tenantId: 'greenwood_high',
      tenantName: 'Greenwood High School',
      schoolOwnerEmail: 'admin@greenwood.edu',
      planCode: 'professional',
      seatLimit: 250,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );

    await db.createOrUpdateTenantLicense(
      tenantId: 'riverside_academy',
      tenantName: 'Riverside Academy',
      schoolOwnerEmail: 'admin@riverside.edu',
      planCode: 'starter',
      seatLimit: 100,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );

    await db.createOrUpdateTenantLicense(
      tenantId: 'oakwood_school',
      tenantName: 'Oakwood School',
      schoolOwnerEmail: 'admin@oakwood.edu',
      planCode: 'enterprise',
      seatLimit: 500,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
  }

  group('TenantLicensingPage Search', () {
    testWidgets('displays search field with correct placeholder',
        (WidgetTester tester) async {
      try {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify search field exists
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search by school name'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('filters tenants by case-insensitive substring match',
        (WidgetTester tester) async {
      try {
      await createTestTenants(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the search field
      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );

      // Verify all tenants are initially visible
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsOneWidget);
      expect(find.text('Oakwood School'), findsOneWidget);

      // Search for "wood" (should match Greenwood and Oakwood)
      await tester.enterText(searchField, 'wood');
      // Wait for debounce (300ms) plus some buffer
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should show Greenwood and Oakwood, but not Riverside
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Oakwood School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsNothing);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('search is case-insensitive', (WidgetTester tester) async {
      await createTestTenants(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );

      // Search with uppercase (should still match)
      await tester.enterText(searchField, 'RIVERSIDE');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Riverside Academy'), findsOneWidget);
      expect(find.text('Greenwood High School'), findsNothing);
      expect(find.text('Oakwood School'), findsNothing);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state message when no matches',
        (WidgetTester tester) async {
      try {
      await createTestTenants(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );

      // Search for something that doesn't exist
      await tester.enterText(searchField, 'nonexistent');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No tenants match the current filters.'), findsOneWidget);
      expect(find.text('Greenwood High School'), findsNothing);
      expect(find.text('Riverside Academy'), findsNothing);
      expect(find.text('Oakwood School'), findsNothing);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('clear button clears search and shows all tenants',
        (WidgetTester tester) async {
      try {
      await createTestTenants(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );

      // Search for "wood"
      await tester.enterText(searchField, 'wood');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify filtered results
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All tenants should be visible again
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsOneWidget);
      expect(find.text('Oakwood School'), findsOneWidget);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('debounces search input (300ms)', (WidgetTester tester) async {
      await createTestTenants(database);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );

      // Enter text but don't wait for debounce
      await tester.enterText(searchField, 'wood');
      await tester.pump(const Duration(milliseconds: 100));

      // Should still show all tenants (debounce not complete)
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsOneWidget);
      expect(find.text('Oakwood School'), findsOneWidget);

      // Wait for debounce to complete
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Now should show filtered results
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Oakwood School'), findsOneWidget);
      expect(find.text('Riverside Academy'), findsNothing);

      // Properly dispose the widget to clean up timers
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });
  });
}
