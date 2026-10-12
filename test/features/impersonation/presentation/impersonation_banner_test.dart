import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/services/audit_log_service.dart';
import 'package:scholify/core/services/impersonation_service.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/impersonation/presentation/impersonation_banner.dart';

/// Widget tests for ImpersonationBanner (Q3.3, Q3.4)
///
/// Covers the banner wired into the Foundation Shell during the UI-wiring pass:
/// - hidden when no impersonation is active
/// - shows the impersonated tenant name while active
/// - tapping the banner ends impersonation
void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  late ImpersonationService impersonationService;

  setUp(() {
    // In-memory database, mirroring test/core/services/impersonation_service_test.dart
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    gateway.setMockAuthModel({
      'id': 'superadmin_001',
      'email': 'superadmin@test.com',
      'role': 'superadmin',
    });
    impersonationService = ImpersonationService(
      tenantContext: tenantContext,
      auditLogService: AuditLogService(
        database: database,
        tenantContext: tenantContext,
        gateway: gateway,
      ),
    );
    tenantContext.setTenant(
      tenantId: '',
      tenantName: '',
      role: 'superadmin',
      isSuperAdmin: true,
    );
  });

  tearDown(() {
    // NOTE: close() is not awaited here. Awaiting it hangs inside
    // testWidgets' FakeAsync zone when the in-memory drift DB has writes.
    // In-memory DBs are reclaimed by GC; close is best-effort here.
    unawaited(database.close());
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ImpersonationBanner(impersonationService: impersonationService),
      ),
    );
  }

  group('ImpersonationBanner', () {
    testWidgets('renders nothing when impersonation is inactive',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ImpersonationBanner), findsOneWidget);
      expect(find.textContaining('Impersonating'), findsNothing);
    });

    testWidgets('shows impersonated tenant name while active',
        (WidgetTester tester) async {
      await impersonationService.startImpersonation(
        'tenant_001',
        'Test School',
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Test School'), findsOneWidget);
      expect(find.textContaining('tap to exit'), findsOneWidget);
    });

    testWidgets('tapping the banner ends impersonation',
        (WidgetTester tester) async {
      await impersonationService.startImpersonation(
        'tenant_001',
        'Test School',
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(impersonationService.isImpersonating, isTrue);

      await tester.tap(find.textContaining('Test School'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(impersonationService.isImpersonating, isFalse);
      expect(find.text('Impersonation ended'), findsOneWidget);
      expect(find.textContaining('Impersonating:'), findsNothing);
    });
  });
}
