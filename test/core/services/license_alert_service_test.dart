import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/license_alert_service.dart';
import 'package:drift/native.dart';

void main() {
  late AppLocalDatabase database;
  late LicenseAlertService alertService;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create license alert service
    alertService = LicenseAlertService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('LicenseAlertService - computeAlertTier', () {
    test('returns expired when expiresAt is in the past', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 1, 10); // 5 days ago
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.expired));
    });

    test('returns urgent7 when 7 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 1, 22); // 7 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.urgent7));
    });

    test('returns urgent7 when 0 days remaining (expires today)', () {
      final now = DateTime(2024, 1, 15, 10, 0);
      final expiresAt = DateTime(2024, 1, 15, 23, 59); // Same day
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.urgent7));
    });

    test('returns alert14 when 14 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 1, 29); // 14 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.alert14));
    });

    test('returns alert14 when 8 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 1, 23); // 8 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.alert14));
    });

    test('returns warning30 when 30 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 2, 14); // 30 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.warning30));
    });

    test('returns warning30 when 15 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 1, 30); // 15 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.warning30));
    });

    test('returns none when more than 30 days remaining', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 2, 20); // 36 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.none));
    });

    test('returns none when 31 days remaining (boundary)', () {
      final now = DateTime(2024, 1, 15);
      final expiresAt = DateTime(2024, 2, 15); // 31 days from now
      
      final tier = alertService.computeAlertTier(expiresAt, now);
      
      expect(tier, equals(AlertTier.none));
    });
  });

  group('LicenseAlertService - computeAlerts', () {
    test('returns empty list when no licenses provided', () {
      final now = DateTime(2024, 1, 15);
      final licenses = <TenantLicenseView>[];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, isEmpty);
    });

    test('excludes inactive licenses', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: false, // Inactive
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 20), // 5 days from now
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, isEmpty);
    });

    test('excludes licenses with null expiry date', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: null, // No expiry
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, isEmpty);
    });

    test('excludes licenses with no alert (more than 30 days)', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 3, 1), // 46 days from now
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, isEmpty);
    });

    test('includes license with warning30 tier', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 2, 10), // 26 days from now
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, hasLength(1));
      expect(alerts[0].tenantId, equals('tenant_001'));
      expect(alerts[0].tenantName, equals('Test School'));
      expect(alerts[0].tier, equals(AlertTier.warning30));
      expect(alerts[0].daysRemaining, equals(26));
    });

    test('includes license with alert14 tier', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 25), // 10 days from now
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, hasLength(1));
      expect(alerts[0].tier, equals(AlertTier.alert14));
      expect(alerts[0].daysRemaining, equals(10));
    });

    test('includes license with urgent7 tier', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 20), // 5 days from now
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, hasLength(1));
      expect(alerts[0].tier, equals(AlertTier.urgent7));
      expect(alerts[0].daysRemaining, equals(5));
    });

    test('includes expired license', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          schoolOwnerEmail: 'owner@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 10), // 5 days ago
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, hasLength(1));
      expect(alerts[0].tier, equals(AlertTier.expired));
      expect(alerts[0].daysRemaining, equals(-5));
    });

    test('processes multiple licenses with different tiers', () {
      final now = DateTime(2024, 1, 15);
      final licenses = [
        // Expired
        TenantLicenseView(
          licenseId: 'lic_001',
          tenantId: 'tenant_001',
          tenantName: 'Expired School',
          schoolOwnerEmail: 'owner1@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 10),
          updatedAt: DateTime(2024, 1, 1),
        ),
        // Urgent7
        TenantLicenseView(
          licenseId: 'lic_002',
          tenantId: 'tenant_002',
          tenantName: 'Urgent School',
          schoolOwnerEmail: 'owner2@test.com',
          planCode: 'professional',
          seatLimit: 200,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 20),
          updatedAt: DateTime(2024, 1, 1),
        ),
        // Alert14
        TenantLicenseView(
          licenseId: 'lic_003',
          tenantId: 'tenant_003',
          tenantName: 'Alert School',
          schoolOwnerEmail: 'owner3@test.com',
          planCode: 'enterprise',
          seatLimit: 500,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 27),
          updatedAt: DateTime(2024, 1, 1),
        ),
        // Warning30
        TenantLicenseView(
          licenseId: 'lic_004',
          tenantId: 'tenant_004',
          tenantName: 'Warning School',
          schoolOwnerEmail: 'owner4@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 2, 10),
          updatedAt: DateTime(2024, 1, 1),
        ),
        // None (should be excluded)
        TenantLicenseView(
          licenseId: 'lic_005',
          tenantId: 'tenant_005',
          tenantName: 'Safe School',
          schoolOwnerEmail: 'owner5@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 3, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        // Inactive (should be excluded)
        TenantLicenseView(
          licenseId: 'lic_006',
          tenantId: 'tenant_006',
          tenantName: 'Inactive School',
          schoolOwnerEmail: 'owner6@test.com',
          planCode: 'starter',
          seatLimit: 100,
          isActive: false,
          issuedAt: DateTime(2023, 1, 1),
          expiresAt: DateTime(2024, 1, 20),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      
      final alerts = alertService.computeAlerts(licenses, now);
      
      expect(alerts, hasLength(4));
      expect(alerts[0].tier, equals(AlertTier.expired));
      expect(alerts[1].tier, equals(AlertTier.urgent7));
      expect(alerts[2].tier, equals(AlertTier.alert14));
      expect(alerts[3].tier, equals(AlertTier.warning30));
    });
  });

  group('LicenseAlertService - watchAlerts', () {
    test('returns stream of alerts', () async {
      // This is a basic test to verify the stream is created
      // In a real scenario, we would populate the database and verify the stream emits correct data
      
      final stream = alertService.watchAlerts();
      
      expect(stream, isA<Stream<List<LicenseAlert>>>());
    });
  });

  group('LicenseAlert - equality', () {
    test('two alerts with same values are equal', () {
      final alert1 = LicenseAlert(
        tenantId: 'tenant_001',
        tenantName: 'Test School',
        expiresAt: DateTime(2024, 1, 20),
        daysRemaining: 5,
        tier: AlertTier.urgent7,
      );
      
      final alert2 = LicenseAlert(
        tenantId: 'tenant_001',
        tenantName: 'Test School',
        expiresAt: DateTime(2024, 1, 20),
        daysRemaining: 5,
        tier: AlertTier.urgent7,
      );
      
      expect(alert1, equals(alert2));
      expect(alert1.hashCode, equals(alert2.hashCode));
    });

    test('two alerts with different values are not equal', () {
      final alert1 = LicenseAlert(
        tenantId: 'tenant_001',
        tenantName: 'Test School',
        expiresAt: DateTime(2024, 1, 20),
        daysRemaining: 5,
        tier: AlertTier.urgent7,
      );
      
      final alert2 = LicenseAlert(
        tenantId: 'tenant_002',
        tenantName: 'Other School',
        expiresAt: DateTime(2024, 1, 25),
        daysRemaining: 10,
        tier: AlertTier.alert14,
      );
      
      expect(alert1, isNot(equals(alert2)));
    });
  });
}
