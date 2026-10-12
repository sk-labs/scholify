import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/dashboard/presentation/dashboard_summary_cards.dart';

/// Widget tests for DashboardSummaryCards (Q4)
///
/// Covers the metric cards wired into the superadmin dashboard:
/// Total Tenants, Active, At Risk, Expiring Soon (<=30d).
void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  late SyncEngine syncEngine;

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
      home: Scaffold(
        body: DashboardSummaryCards(syncEngine: syncEngine),
      ),
    );
  }

  Future<void> seedTenant({
    required String tenantId,
    required String tenantName,
    required int seatLimit,
    required int activeStudents,
    required DateTime expiresAt,
    bool isActive = true,
  }) async {
    if (isActive) {
      await database.createOrUpdateTenantLicense(
        tenantId: tenantId,
        tenantName: tenantName,
        schoolOwnerEmail: 'owner@$tenantId.test',
        planCode: 'professional',
        seatLimit: seatLimit,
        expiresAt: expiresAt,
      );
    } else {
      await database.upsertTenantLicenseFromRemote(
        licenseId: 'lic_$tenantId',
        tenantId: tenantId,
        tenantName: tenantName,
        schoolOwnerEmail: 'owner@$tenantId.test',
        planCode: 'starter',
        seatLimit: seatLimit,
        isActive: false,
        issuedAt: DateTime.now().subtract(const Duration(days: 100)),
        updatedAt: DateTime.now().subtract(const Duration(days: 100)),
        expiresAt: expiresAt,
      );
    }
    await database.into(database.tenantUsageMetricEntries).insert(
          TenantUsageMetricEntriesCompanion.insert(
            id: 'metric_$tenantId',
            tenantId: tenantId,
            periodKey: '2026-10',
            activeStudents: Value(activeStudents),
          ),
        );
  }

  group('DashboardSummaryCards', () {
    testWidgets('shows zero metrics when no tenants exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Total Tenants'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('At Risk'), findsOneWidget);
      expect(find.text('Expiring Soon (≤30d)'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('computes total, active, at-risk and expiring metrics',
        (WidgetTester tester) async {
      final now = DateTime.now();
      // At-risk via seat pressure (95/100 >= 90%) and expiring within 30 days
      await seedTenant(
        tenantId: 'tenant_a',
        tenantName: 'Alpha School',
        seatLimit: 100,
        activeStudents: 95,
        expiresAt: now.add(const Duration(days: 10)),
      );
      // Healthy active tenant, far from expiry
      await seedTenant(
        tenantId: 'tenant_b',
        tenantName: 'Beta School',
        seatLimit: 100,
        activeStudents: 10,
        expiresAt: now.add(const Duration(days: 200)),
      );
      // Suspended tenant: counted in total, excluded from active/expiring
      await seedTenant(
        tenantId: 'tenant_c',
        tenantName: 'Gamma School',
        seatLimit: 50,
        activeStudents: 0,
        expiresAt: now.add(const Duration(days: 200)),
        isActive: false,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Total Tenants'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('At Risk'), findsOneWidget);
      expect(find.text('Expiring Soon (≤30d)'), findsOneWidget);
      // At-risk and expiring-soon are both 1 (tenant_a)
      expect(find.text('1'), findsNWidgets(2));
    });
  });
}
