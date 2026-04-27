import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/license_alert_service.dart';
import 'package:drift/native.dart';
import 'dart:math';

/// Property-based tests for LicenseAlertService
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 2.4 Write property test for LicenseAlertService
/// 
/// This test suite validates:
/// - Property 9: License expiry alert tier computation
/// 
/// Requirements: H4.1, H4.2, H4.3, H4.4, H4.5, H4.6

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

  group('Property 9: License expiry alert tier computation', () {
    /// **Validates: Requirements H4.1, H4.2, H4.3, H4.4, H4.5, H4.6**
    /// 
    /// For any license expiry date and current date, the alert tier SHALL be computed as:
    /// - expired if expiresAt < now
    /// - urgent7 if 0 <= daysRemaining <= 7
    /// - alert14 if 8 <= daysRemaining <= 14
    /// - warning30 if 15 <= daysRemaining <= 30
    /// - none if daysRemaining > 30 or expiresAt is null
    test('alert tier is correctly computed for all possible date pairs', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random current date (between 2020 and 2030)
        final now = _generateRandomDate(random, 2020, 2030);
        
        // Generate random expiry date (between -100 and +100 days from now)
        final daysOffset = random.nextInt(201) - 100; // -100 to +100
        final expiresAt = now.add(Duration(days: daysOffset));
        
        // Compute alert tier
        final tier = alertService.computeAlertTier(expiresAt, now);
        
        // Calculate expected days remaining
        final daysRemaining = expiresAt.difference(now).inDays;
        
        // Assert: tier matches expected value based on days remaining
        if (daysRemaining < 0) {
          expect(
            tier,
            equals(AlertTier.expired),
            reason: 'Expected expired for daysRemaining=$daysRemaining (expiresAt=$expiresAt, now=$now)',
          );
        } else if (daysRemaining <= 7) {
          expect(
            tier,
            equals(AlertTier.urgent7),
            reason: 'Expected urgent7 for daysRemaining=$daysRemaining (expiresAt=$expiresAt, now=$now)',
          );
        } else if (daysRemaining <= 14) {
          expect(
            tier,
            equals(AlertTier.alert14),
            reason: 'Expected alert14 for daysRemaining=$daysRemaining (expiresAt=$expiresAt, now=$now)',
          );
        } else if (daysRemaining <= 30) {
          expect(
            tier,
            equals(AlertTier.warning30),
            reason: 'Expected warning30 for daysRemaining=$daysRemaining (expiresAt=$expiresAt, now=$now)',
          );
        } else {
          expect(
            tier,
            equals(AlertTier.none),
            reason: 'Expected none for daysRemaining=$daysRemaining (expiresAt=$expiresAt, now=$now)',
          );
        }
      }
    });

    test('alert tier boundaries are correctly handled', () {
      const numIterations = 100;
      final random = Random(123);
      
      // Test boundary conditions explicitly
      final boundaries = [
        -1,  // Just expired
        0,   // Expires today (urgent7 boundary)
        7,   // Last day of urgent7
        8,   // First day of alert14
        14,  // Last day of alert14
        15,  // First day of warning30
        30,  // Last day of warning30
        31,  // First day of none
      ];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2020, 2030);
        
        for (final daysOffset in boundaries) {
          final expiresAt = now.add(Duration(days: daysOffset));
          final tier = alertService.computeAlertTier(expiresAt, now);
          final daysRemaining = expiresAt.difference(now).inDays;
          
          // Verify tier matches expected value at boundary
          final expectedTier = _expectedTierForDaysRemaining(daysRemaining);
          
          expect(
            tier,
            equals(expectedTier),
            reason: 'Boundary test failed: daysRemaining=$daysRemaining, '
                'expected=$expectedTier, got=$tier (expiresAt=$expiresAt, now=$now)',
          );
        }
      }
    });

    test('alert tier computation is deterministic', () {
      const numIterations = 100;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2020, 2030);
        final daysOffset = random.nextInt(201) - 100;
        final expiresAt = now.add(Duration(days: daysOffset));
        
        // Compute tier multiple times
        final tier1 = alertService.computeAlertTier(expiresAt, now);
        final tier2 = alertService.computeAlertTier(expiresAt, now);
        final tier3 = alertService.computeAlertTier(expiresAt, now);
        
        // Assert: all results are identical (deterministic)
        expect(
          tier1,
          equals(tier2),
          reason: 'Alert tier computation should be deterministic',
        );
        expect(
          tier2,
          equals(tier3),
          reason: 'Alert tier computation should be deterministic',
        );
      }
    });

    test('alert tier transitions are monotonic with time', () {
      const numIterations = 100;
      final random = Random(789);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Fix an expiry date
        final expiresAt = _generateRandomDate(random, 2024, 2025);
        
        // Generate a sequence of "now" dates approaching the expiry
        // Start from 60 days before expiry
        final startDate = expiresAt.subtract(const Duration(days: 60));
        
        AlertTier? previousTier;
        int previousTierValue = -1;
        
        // Move forward in time, day by day
        for (int day = 0; day <= 70; day++) {
          final now = startDate.add(Duration(days: day));
          final tier = alertService.computeAlertTier(expiresAt, now);
          final tierValue = _tierToValue(tier);
          
          // Assert: tier value should never decrease as time progresses
          // (none=0, warning30=1, alert14=2, urgent7=3, expired=4)
          expect(
            tierValue,
            greaterThanOrEqualTo(previousTierValue),
            reason: 'Alert tier should never decrease as time progresses. '
                'Day $day: previous=$previousTier (value=$previousTierValue), '
                'current=$tier (value=$tierValue), expiresAt=$expiresAt, now=$now',
          );
          
          previousTier = tier;
          previousTierValue = tierValue;
        }
      }
    });

    test('computeAlerts filters licenses correctly', () async {
      const numIterations = 50;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2024, 2025);
        
        // Generate random licenses with various states
        final numLicenses = random.nextInt(20) + 5;
        final licenses = _generateRandomLicenses(random, numLicenses, now);
        
        // Compute alerts
        final alerts = alertService.computeAlerts(licenses, now);
        
        // Assert: all alerts correspond to active licenses
        for (final alert in alerts) {
          final license = licenses.firstWhere((l) => l.tenantId == alert.tenantId);
          
          expect(
            license.isActive,
            isTrue,
            reason: 'Alert should only be generated for active licenses',
          );
          
          expect(
            license.expiresAt,
            isNotNull,
            reason: 'Alert should only be generated for licenses with expiry date',
          );
        }
        
        // Assert: no alerts have tier 'none'
        for (final alert in alerts) {
          expect(
            alert.tier,
            isNot(equals(AlertTier.none)),
            reason: 'Alerts with tier "none" should be filtered out',
          );
        }
        
        // Assert: all active licenses with non-null expiry and tier != none are included
        final expectedAlertCount = licenses.where((l) {
          if (!l.isActive) return false;
          if (l.expiresAt == null) return false;
          
          final tier = alertService.computeAlertTier(l.expiresAt!, now);
          return tier != AlertTier.none;
        }).length;
        
        expect(
          alerts.length,
          equals(expectedAlertCount),
          reason: 'All qualifying licenses should generate alerts',
        );
      }
    });

    test('computeAlerts handles null expiry dates correctly', () async {
      const numIterations = 50;
      final random = Random(131415);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2024, 2025);
        
        // Generate licenses with mix of null and non-null expiry dates
        final licenses = <TenantLicenseView>[];
        final numLicenses = random.nextInt(20) + 5;
        
        for (int i = 0; i < numLicenses; i++) {
          final hasExpiry = random.nextBool();
          
          licenses.add(TenantLicenseView(
            licenseId: 'lic_$iteration\_$i',
            tenantId: 'tenant_$iteration\_$i',
            tenantName: 'School $i',
            schoolOwnerEmail: 'owner$i@test.com',
            planCode: _randomPlan(random),
            seatLimit: random.nextInt(500) + 50,
            isActive: true,
            issuedAt: now.subtract(Duration(days: random.nextInt(365))),
            expiresAt: hasExpiry ? now.add(Duration(days: random.nextInt(60) - 10)) : null,
            updatedAt: now,
          ));
        }
        
        // Compute alerts
        final alerts = alertService.computeAlerts(licenses, now);
        
        // Assert: no alerts for licenses with null expiry
        for (final alert in alerts) {
          final license = licenses.firstWhere((l) => l.tenantId == alert.tenantId);
          
          expect(
            license.expiresAt,
            isNotNull,
            reason: 'Alerts should not be generated for licenses with null expiry',
          );
        }
        
        // Assert: count matches expected
        final expectedCount = licenses.where((l) {
          if (!l.isActive) return false;
          if (l.expiresAt == null) return false;
          
          final tier = alertService.computeAlertTier(l.expiresAt!, now);
          return tier != AlertTier.none;
        }).length;
        
        expect(
          alerts.length,
          equals(expectedCount),
          reason: 'Alert count should match licenses with non-null expiry and tier != none',
        );
      }
    });

    test('computeAlerts excludes inactive licenses', () async {
      const numIterations = 50;
      final random = Random(161718);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2024, 2025);
        
        // Generate licenses with mix of active and inactive
        final licenses = <TenantLicenseView>[];
        final numLicenses = random.nextInt(20) + 5;
        
        for (int i = 0; i < numLicenses; i++) {
          final isActive = random.nextBool();
          
          licenses.add(TenantLicenseView(
            licenseId: 'lic_$iteration\_$i',
            tenantId: 'tenant_$iteration\_$i',
            tenantName: 'School $i',
            schoolOwnerEmail: 'owner$i@test.com',
            planCode: _randomPlan(random),
            seatLimit: random.nextInt(500) + 50,
            isActive: isActive,
            issuedAt: now.subtract(Duration(days: random.nextInt(365))),
            expiresAt: now.add(Duration(days: random.nextInt(60) - 10)),
            updatedAt: now,
          ));
        }
        
        // Compute alerts
        final alerts = alertService.computeAlerts(licenses, now);
        
        // Assert: all alerts are for active licenses
        for (final alert in alerts) {
          final license = licenses.firstWhere((l) => l.tenantId == alert.tenantId);
          
          expect(
            license.isActive,
            isTrue,
            reason: 'Alerts should only be generated for active licenses',
          );
        }
        
        // Assert: no inactive licenses in alerts
        final inactiveLicenseIds = licenses
            .where((l) => !l.isActive)
            .map((l) => l.tenantId)
            .toSet();
        
        for (final alert in alerts) {
          expect(
            inactiveLicenseIds.contains(alert.tenantId),
            isFalse,
            reason: 'Inactive licenses should not generate alerts',
          );
        }
      }
    });

    test('alert daysRemaining matches computed value', () async {
      const numIterations = 100;
      final random = Random(192021);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final now = _generateRandomDate(random, 2024, 2025);
        
        // Generate licenses
        final licenses = _generateRandomLicenses(random, 10, now);
        
        // Compute alerts
        final alerts = alertService.computeAlerts(licenses, now);
        
        // Assert: daysRemaining in alert matches actual calculation
        for (final alert in alerts) {
          final expectedDaysRemaining = alert.expiresAt.difference(now).inDays;
          
          expect(
            alert.daysRemaining,
            equals(expectedDaysRemaining),
            reason: 'Alert daysRemaining should match expiresAt.difference(now).inDays',
          );
        }
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random date between startYear and endYear
DateTime _generateRandomDate(Random random, int startYear, int endYear) {
  final year = startYear + random.nextInt(endYear - startYear + 1);
  final month = random.nextInt(12) + 1;
  final day = random.nextInt(28) + 1; // Use 28 to avoid month-end issues
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  
  return DateTime(year, month, day, hour, minute);
}

/// Returns the expected alert tier for a given days remaining value
AlertTier _expectedTierForDaysRemaining(int daysRemaining) {
  if (daysRemaining < 0) {
    return AlertTier.expired;
  } else if (daysRemaining <= 7) {
    return AlertTier.urgent7;
  } else if (daysRemaining <= 14) {
    return AlertTier.alert14;
  } else if (daysRemaining <= 30) {
    return AlertTier.warning30;
  } else {
    return AlertTier.none;
  }
}

/// Converts alert tier to numeric value for monotonicity testing
int _tierToValue(AlertTier tier) {
  switch (tier) {
    case AlertTier.none:
      return 0;
    case AlertTier.warning30:
      return 1;
    case AlertTier.alert14:
      return 2;
    case AlertTier.urgent7:
      return 3;
    case AlertTier.expired:
      return 4;
  }
}

/// Generates random licenses for testing
List<TenantLicenseView> _generateRandomLicenses(
  Random random,
  int count,
  DateTime now,
) {
  return List.generate(count, (i) {
    final isActive = random.nextBool();
    final hasExpiry = random.nextBool();
    final daysOffset = random.nextInt(100) - 20; // -20 to +80 days
    
    return TenantLicenseView(
      licenseId: 'lic_$i',
      tenantId: 'tenant_$i',
      tenantName: 'School $i',
      schoolOwnerEmail: 'owner$i@test.com',
      planCode: _randomPlan(random),
      seatLimit: random.nextInt(500) + 50,
      isActive: isActive,
      issuedAt: now.subtract(Duration(days: random.nextInt(365))),
      expiresAt: hasExpiry ? now.add(Duration(days: daysOffset)) : null,
      updatedAt: now,
    );
  });
}

/// Returns a random plan code
String _randomPlan(Random random) {
  final plans = ['starter', 'professional', 'enterprise'];
  return plans[random.nextInt(plans.length)];
}
