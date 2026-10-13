import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/superadmin/presentation/tenant_licensing_page.dart';

/// Widget tests for TenantLicensingPage row actions (Q1, Q3)
///
/// Covers the actions wired into the tenant list rows:
/// - Impersonate action starts impersonation for the row's tenant
/// - Details action navigates to TenantDetailPage
void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  late SyncEngine syncEngine;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    tenantContext.setTenant(
      tenantId: '',
      tenantName: '',
      role: 'superadmin',
      isSuperAdmin: true,
    );
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    gateway.setMockAuthModel({
      'id': 'superadmin_001',
      'email': 'superadmin@test.com',
      'role': 'superadmin',
    });
    syncEngine = SyncEngine(
      database: database,
      pocketbaseGateway: gateway,
      tenantContext: tenantContext,
    );
  });

  tearDown(() {
    // NOTE: database.close() is intentionally not called. Awaiting close()
    // hangs in testWidgets' FakeAsync zone, and calling it (even unawaited)
    // leaves drift stream-cleanup timers pending. In-memory DBs are
    // reclaimed by GC. Stream timers are flushed at the end of each test.
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: TenantLicensingPage(
        tenantContext: tenantContext,
        syncEngine: syncEngine,
      ),
    );
  }

  Future<void> seedTenant() async {
    await database.createOrUpdateTenantLicense(
      tenantId: 'greenwood_high',
      tenantName: 'Greenwood High School',
      schoolOwnerEmail: 'admin@greenwood.edu',
      planCode: 'professional',
      seatLimit: 250,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
  }

  group('TenantLicensingPage row actions', () {
    testWidgets('Impersonate action starts impersonation for the row tenant',
        (WidgetTester tester) async {
      // Use a large surface: the page overflows the default 800x600 test
      // viewport (RenderFlex overflow).
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await seedTenant();
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.widgetWithText(OutlinedButton, 'Impersonate'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Impersonate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Now impersonating Greenwood High School'),
        findsOneWidget,
      );
      expect(tenantContext.tenantId, equals('greenwood_high'));

      // Dispose to flush the search debounce timer and drift's
      // stream-cleanup timer before the test ends.
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Details action navigates to TenantDetailPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await seedTenant();
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tenant Details'), findsOneWidget);

      // Dispose to flush the search debounce timer and drift's
      // stream-cleanup timer before the test ends.
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
