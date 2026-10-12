import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/services/audit_log_service.dart';
import 'package:scholify/core/services/impersonation_service.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/tenant_detail/presentation/tenant_detail_page.dart';

/// Widget tests for TenantDetailPage (Q1)
///
/// Covers the tenant detail view reachable from the tenant lists:
/// - not-found state for an unknown tenant id
/// - detail sections render for a seeded tenant
void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  late SyncEngine syncEngine;
  late ImpersonationService impersonationService;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    syncEngine = SyncEngine(
      database: database,
      pocketbaseGateway: gateway,
      tenantContext: tenantContext,
    );
    impersonationService = ImpersonationService(
      tenantContext: tenantContext,
      auditLogService: AuditLogService(
        database: database,
        tenantContext: tenantContext,
        gateway: gateway,
      ),
    );
  });

  tearDown(() {
    // NOTE: database.close() is intentionally not called. Awaiting close()
    // hangs in testWidgets' FakeAsync zone, and calling it (even unawaited)
    // leaves drift stream-cleanup timers pending. In-memory DBs are
    // reclaimed by GC. Stream timers are flushed at the end of each test.
  });

  Widget createTestWidget(String tenantId) {
    return MaterialApp(
      home: TenantDetailPage(
        tenantId: tenantId,
        syncEngine: syncEngine,
        impersonationService: impersonationService,
      ),
    );
  }

  Future<void> seedTenant() async {
    await database.createOrUpdateTenantLicense(
      tenantId: 'tenant_001',
      tenantName: 'Test School',
      schoolOwnerEmail: 'owner@test.school',
      planCode: 'professional',
      seatLimit: 250,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
    await database.into(database.tenantUsageMetricEntries).insert(
          TenantUsageMetricEntriesCompanion.insert(
            id: 'metric_tenant_001',
            tenantId: 'tenant_001',
            periodKey: '2026-10',
            activeStudents: const Value(120),
            activeStaff: const Value(15),
          ),
        );
  }

  group('TenantDetailPage', () {
    testWidgets('shows not-found state for unknown tenant',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget('unknown_tenant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tenant Details'), findsOneWidget);
      expect(find.text('Tenant not found'), findsOneWidget);

      // Flush drift's stream-cleanup timer before test end.
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('renders tenant details for a known tenant',
        (WidgetTester tester) async {
      await seedTenant();
      await tester.pumpWidget(createTestWidget('tenant_001'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Test School'), findsOneWidget);
      expect(find.text('Usage Statistics'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);

      // Flush drift's stream-cleanup timer before test end.
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
