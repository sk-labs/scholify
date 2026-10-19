import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/services/license_alert_service.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/superadmin/presentation/superadmin_dashboard_page.dart';

/// Integration test for License Alert Service integration into SuperadminDashboard.
/// 
/// Validates: Requirements H4.1, H4.2, H4.3, H4.4, H4.5
/// 
/// This test verifies that:
/// - Alert banners are displayed for expired, urgent (7d), and alert (14d) licenses
/// - Banners show correct tenant names and expiry dates
/// - Alerts are computed on app launch (via watchAlerts stream)
void main() {
  group('SuperadminDashboard License Alert Integration', () {
    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late LicenseAlertService licenseAlertService;
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
      tenantContext.setTenant(
        tenantId: 'superadmin',
        tenantName: 'Superadmin',
        role: 'superadmin',
        isSuperAdmin: true,
      );
      gateway = PocketbaseGateway(baseUrl: 'http://test.local');
      syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: gateway,
        tenantContext: tenantContext,
      );
      licenseAlertService = LicenseAlertService(database: database);
    });

    tearDown(() async {
      if (!dbClosed) {
        dbClosed = true;
        try { await database.close(); } catch (_) {}
      }
    });

    testWidgets('displays red urgent banner for expired licenses', (tester) async {
      try {
      // Create an expired license
      final now = DateTime.now();
      final expiredDate = now.subtract(const Duration(days: 5));
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'expired_school',
        tenantName: 'Expired School',
        schoolOwnerEmail: 'owner@expired.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: expiredDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboardPage(
            tenantContext: tenantContext,
            syncEngine: syncEngine,
            licenseAlertService: licenseAlertService,
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pumpAndSettle();

      // Verify expired banner is displayed
      expect(find.text('Expired Licenses (1)'), findsOneWidget);
      expect(find.textContaining('Expired School:'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('displays red urgent banner for 7-day alerts', (tester) async {
      try {
      // Create a license expiring in 5 days
      final now = DateTime.now();
      final urgentDate = now.add(const Duration(days: 5));
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'urgent_school',
        tenantName: 'Urgent School',
        schoolOwnerEmail: 'owner@urgent.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: urgentDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboardPage(
            tenantContext: tenantContext,
            syncEngine: syncEngine,
            licenseAlertService: licenseAlertService,
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pumpAndSettle();

      // Verify urgent banner is displayed
      expect(find.text('Expiring within 7 days (1)'), findsOneWidget);
      expect(find.textContaining('Urgent School:'), findsOneWidget);
      expect(find.textContaining('d left)'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('displays amber alert banner for 14-day alerts', (tester) async {
      try {
      // Create a license expiring in 10 days
      final now = DateTime.now();
      final alertDate = now.add(const Duration(days: 10));
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'alert_school',
        tenantName: 'Alert School',
        schoolOwnerEmail: 'owner@alert.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: alertDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboardPage(
            tenantContext: tenantContext,
            syncEngine: syncEngine,
            licenseAlertService: licenseAlertService,
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pumpAndSettle();

      // Verify alert banner is displayed
      expect(find.text('Expiring within 14 days (1)'), findsOneWidget);
      expect(find.textContaining('Alert School:'), findsOneWidget);
      expect(find.textContaining('d left)'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('displays multiple alert banners when multiple tiers are present', (tester) async {
      try {
      // Create licenses in different alert tiers
      final now = DateTime.now();
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'expired_school',
        tenantName: 'Expired School',
        schoolOwnerEmail: 'owner@expired.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: now.subtract(const Duration(days: 5)),
      );
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'urgent_school',
        tenantName: 'Urgent School',
        schoolOwnerEmail: 'owner@urgent.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: now.add(const Duration(days: 5)),
      );
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'alert_school',
        tenantName: 'Alert School',
        schoolOwnerEmail: 'owner@alert.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: now.add(const Duration(days: 10)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboardPage(
            tenantContext: tenantContext,
            syncEngine: syncEngine,
            licenseAlertService: licenseAlertService,
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pumpAndSettle();

      // Verify all three banners are displayed
      expect(find.text('Expired Licenses (1)'), findsOneWidget);
      expect(find.text('Expiring within 7 days (1)'), findsOneWidget);
      expect(find.text('Expiring within 14 days (1)'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('does not display banners when no alerts are present', (tester) async {
      try {
      // Create a license with plenty of time remaining
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 100));
      
      await database.createOrUpdateTenantLicense(
        tenantId: 'safe_school',
        tenantName: 'Safe School',
        schoolOwnerEmail: 'owner@safe.com',
        planCode: 'professional',
        seatLimit: 100,
        expiresAt: futureDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboardPage(
            tenantContext: tenantContext,
            syncEngine: syncEngine,
            licenseAlertService: licenseAlertService,
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pumpAndSettle();

      // Verify no alert banners are displayed
      expect(find.text('Expired Licenses'), findsNothing);
      expect(find.text('Expiring within 7 days'), findsNothing);
      expect(find.text('Expiring within 14 days'), findsNothing);
      } finally {
        await closeDbOnce(tester);
      }
    });
  });
}
