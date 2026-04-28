import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/impersonation_service.dart';
import 'package:scholify/core/services/audit_log_service.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:drift/native.dart';

void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late AuditLogService auditLogService;
  late PocketbaseGateway gateway;
  late ImpersonationService impersonationService;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create tenant context
    tenantContext = TenantContext();
    
    // Create PocketBase gateway (mock for testing)
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    
    // Mock authentication for audit logging
    gateway.setMockAuthModel({
      'id': 'superadmin_001',
      'email': 'superadmin@test.com',
      'role': 'superadmin',
    });
    
    // Create audit log service
    auditLogService = AuditLogService(
      database: database,
      tenantContext: tenantContext,
      gateway: gateway,
    );
    
    // Create impersonation service
    impersonationService = ImpersonationService(
      tenantContext: tenantContext,
      auditLogService: auditLogService,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('ImpersonationService - Initial State', () {
    test('isImpersonating is false initially', () {
      expect(impersonationService.isImpersonating, isFalse);
    });

    test('impersonatedTenantName is null initially', () {
      expect(impersonationService.impersonatedTenantName, isNull);
    });

    test('impersonatedTenantId is null initially', () {
      expect(impersonationService.impersonatedTenantId, isNull);
    });
  });

  group('ImpersonationService - startImpersonation', () {
    test('sets isImpersonating to true', () async {
      // Set up superadmin context
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(impersonationService.isImpersonating, isTrue);
    });

    test('sets impersonatedTenantName correctly', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(impersonationService.impersonatedTenantName, equals('Test School'));
    });

    test('sets impersonatedTenantId correctly', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(impersonationService.impersonatedTenantId, equals('tenant_001'));
    });

    test('updates TenantContext with impersonated tenant', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(tenantContext.tenantId, equals('tenant_001'));
      expect(tenantContext.tenantName, equals('Test School'));
      expect(tenantContext.role, equals('school_owner'));
      expect(tenantContext.isSuperAdmin, isTrue);
    });

    test('throws exception if already impersonating', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(
        () => impersonationService.startImpersonation('tenant_002', 'Other School'),
        throwsA(isA<Exception>()),
      );
    });

    test('notifies listeners when impersonation starts', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      var notified = false;
      impersonationService.addListener(() {
        notified = true;
      });

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      expect(notified, isTrue);
    });

    test('preserves original context for restoration', () async {
      // Set up original superadmin context
      tenantContext.setTenant(
        tenantId: 'superadmin_tenant',
        tenantName: 'Superadmin Org',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      // Context should be changed to impersonated tenant
      expect(tenantContext.tenantId, equals('tenant_001'));
      expect(tenantContext.tenantName, equals('Test School'));
    });
  });

  group('ImpersonationService - endImpersonation', () {
    test('sets isImpersonating to false', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');
      await impersonationService.endImpersonation();

      expect(impersonationService.isImpersonating, isFalse);
    });

    test('clears impersonatedTenantName', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');
      await impersonationService.endImpersonation();

      expect(impersonationService.impersonatedTenantName, isNull);
    });

    test('clears impersonatedTenantId', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');
      await impersonationService.endImpersonation();

      expect(impersonationService.impersonatedTenantId, isNull);
    });

    test('restores original TenantContext when original had no tenant', () async {
      // Original context: superadmin with no tenant
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');
      await impersonationService.endImpersonation();

      // Should restore superadmin context
      expect(tenantContext.role, equals('superadmin'));
      expect(tenantContext.isSuperAdmin, isTrue);
    });

    test('restores original TenantContext when original had a tenant', () async {
      // Original context: superadmin with a tenant
      tenantContext.setTenant(
        tenantId: 'superadmin_tenant',
        tenantName: 'Superadmin Org',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');
      await impersonationService.endImpersonation();

      // Should restore original tenant context
      expect(tenantContext.tenantId, equals('superadmin_tenant'));
      expect(tenantContext.tenantName, equals('Superadmin Org'));
      expect(tenantContext.role, equals('superadmin'));
      expect(tenantContext.isSuperAdmin, isTrue);
    });

    test('throws exception if not currently impersonating', () {
      expect(
        () => impersonationService.endImpersonation(),
        throwsA(isA<Exception>()),
      );
    });

    test('notifies listeners when impersonation ends', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', 'Test School');

      var notified = false;
      impersonationService.addListener(() {
        notified = true;
      });

      await impersonationService.endImpersonation();

      expect(notified, isTrue);
    });
  });

  group('ImpersonationService - Multiple Impersonation Cycles', () {
    test('can start impersonation again after ending', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      // First cycle
      await impersonationService.startImpersonation('tenant_001', 'Test School 1');
      await impersonationService.endImpersonation();

      // Second cycle
      await impersonationService.startImpersonation('tenant_002', 'Test School 2');

      expect(impersonationService.isImpersonating, isTrue);
      expect(impersonationService.impersonatedTenantId, equals('tenant_002'));
      expect(impersonationService.impersonatedTenantName, equals('Test School 2'));
    });

    test('correctly restores context after multiple cycles', () async {
      tenantContext.setTenant(
        tenantId: 'superadmin_tenant',
        tenantName: 'Superadmin Org',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      // First cycle
      await impersonationService.startImpersonation('tenant_001', 'Test School 1');
      await impersonationService.endImpersonation();

      // Second cycle
      await impersonationService.startImpersonation('tenant_002', 'Test School 2');
      await impersonationService.endImpersonation();

      // Should restore original context
      expect(tenantContext.tenantId, equals('superadmin_tenant'));
      expect(tenantContext.tenantName, equals('Superadmin Org'));
      expect(tenantContext.role, equals('superadmin'));
      expect(tenantContext.isSuperAdmin, isTrue);
    });
  });

  group('ImpersonationService - Edge Cases', () {
    test('handles empty tenant name', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      await impersonationService.startImpersonation('tenant_001', '');

      expect(impersonationService.isImpersonating, isTrue);
      expect(impersonationService.impersonatedTenantName, equals(''));
    });

    test('handles special characters in tenant name', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      const specialName = 'Test School & Co. (2024)';
      await impersonationService.startImpersonation('tenant_001', specialName);

      expect(impersonationService.impersonatedTenantName, equals(specialName));
    });

    test('handles very long tenant names', () async {
      tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );

      final longName = 'A' * 500;
      await impersonationService.startImpersonation('tenant_001', longName);

      expect(impersonationService.impersonatedTenantName, equals(longName));
    });
  });
}
