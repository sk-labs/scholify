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

  tearDown(() async {
    await database.close();
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
      await seedTenant();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Impersonate'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Impersonate'));
      await tester.pumpAndSettle();

      expect(
        find.text('Now impersonating Greenwood High School'),
        findsOneWidget,
      );
      expect(tenantContext.tenantId, equals('greenwood_high'));

      // Dispose to clean up the search debounce timer
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });

    testWidgets('Details action navigates to TenantDetailPage',
        (WidgetTester tester) async {
      await seedTenant();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
      await tester.pumpAndSettle();

      expect(find.text('Tenant Details'), findsOneWidget);

      // Dispose to clean up the search debounce timer
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });
  });
}
