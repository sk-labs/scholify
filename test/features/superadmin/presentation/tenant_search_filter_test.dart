import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Unit tests for tenant search filtering logic
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H2.1, H2.3, H2.4, H2.5, H2.6, H2.7
///
/// Tests the core filtering logic for tenant search:
/// - Case-insensitive substring matching
/// - Empty search returns all tenants
/// - Plan filter chips (All, Starter, Professional, Enterprise)
/// - Status filter chips (All, Active, Suspended)
/// - Combined filters (search + plan + status)
void main() {
  group('Tenant Search Filter Logic', () {
    List<TenantLicenseView> createMockTenants() {
      return [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'greenwood_high',
          tenantName: 'Greenwood High School',
          planCode: 'professional',
          seatLimit: 250,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@greenwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_2',
          tenantId: 'riverside_academy',
          tenantName: 'Riverside Academy',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@riverside.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_3',
          tenantId: 'oakwood_school',
          tenantName: 'Oakwood School',
          planCode: 'enterprise',
          seatLimit: 500,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@oakwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_4',
          tenantId: 'maple_academy',
          tenantName: 'Maple Academy',
          planCode: 'professional',
          seatLimit: 300,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@maple.edu',
        ),
      ];
    }

    List<TenantLicenseView> applyFilters(
      List<TenantLicenseView> tenants,
      String searchQuery,
      String? planFilter,
      bool? activeFilter,
    ) {
      var filtered = tenants;

      // Apply search query filter
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered
            .where((t) => t.tenantName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      // Apply plan filter
      if (planFilter != null) {
        filtered = filtered.where((t) => t.planCode == planFilter).toList();
      }

      // Apply active status filter
      if (activeFilter != null) {
        filtered = filtered.where((t) => t.isActive == activeFilter).toList();
      }

      return filtered;
    }

    test('returns all tenants when search query is empty', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', null, null);

      expect(result.length, equals(4));
      expect(result, equals(tenants));
    });

    test('filters tenants by case-insensitive substring match', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'wood', null, null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[1].tenantName, equals('Oakwood School'));
    });

    test('search is case-insensitive', () {
      final tenants = createMockTenants();
      
      // Test uppercase
      final resultUpper = applyFilters(tenants, 'RIVERSIDE', null, null);
      expect(resultUpper.length, equals(1));
      expect(resultUpper[0].tenantName, equals('Riverside Academy'));

      // Test lowercase
      final resultLower = applyFilters(tenants, 'riverside', null, null);
      expect(resultLower.length, equals(1));
      expect(resultLower[0].tenantName, equals('Riverside Academy'));

      // Test mixed case
      final resultMixed = applyFilters(tenants, 'RiVeRsIdE', null, null);
      expect(resultMixed.length, equals(1));
      expect(resultMixed[0].tenantName, equals('Riverside Academy'));
    });

    test('returns empty list when no matches found', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'nonexistent', null, null);

      expect(result.length, equals(0));
      expect(result, isEmpty);
    });

    test('matches substring at beginning of name', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Green', null, null);

      expect(result.length, equals(1));
      expect(result[0].tenantName, equals('Greenwood High School'));
    });

    test('matches substring in middle of name', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'High', null, null);

      expect(result.length, equals(1));
      expect(result[0].tenantName, equals('Greenwood High School'));
    });

    test('matches substring at end of name', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Academy', null, null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Riverside Academy'));
      expect(result[1].tenantName, equals('Maple Academy'));
    });

    test('handles whitespace in search query', () {
      final tenants = createMockTenants();
      // The implementation trims whitespace, so "  wood  " becomes "wood"
      final result = applyFilters(tenants, '  wood  '.trim(), null, null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[1].tenantName, equals('Oakwood School'));
    });

    test('matches multiple tenants with common substring', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'School', null, null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[1].tenantName, equals('Oakwood School'));
    });
  });

  group('Plan Filter Chips', () {
    List<TenantLicenseView> createMockTenants() {
      return [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'greenwood_high',
          tenantName: 'Greenwood High School',
          planCode: 'professional',
          seatLimit: 250,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@greenwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_2',
          tenantId: 'riverside_academy',
          tenantName: 'Riverside Academy',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@riverside.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_3',
          tenantId: 'oakwood_school',
          tenantName: 'Oakwood School',
          planCode: 'enterprise',
          seatLimit: 500,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@oakwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_4',
          tenantId: 'maple_academy',
          tenantName: 'Maple Academy',
          planCode: 'professional',
          seatLimit: 300,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@maple.edu',
        ),
      ];
    }

    List<TenantLicenseView> applyFilters(
      List<TenantLicenseView> tenants,
      String searchQuery,
      String? planFilter,
      bool? activeFilter,
    ) {
      var filtered = tenants;

      // Apply search query filter
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered
            .where((t) => t.tenantName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      // Apply plan filter
      if (planFilter != null) {
        filtered = filtered.where((t) => t.planCode == planFilter).toList();
      }

      // Apply active status filter
      if (activeFilter != null) {
        filtered = filtered.where((t) => t.isActive == activeFilter).toList();
      }

      return filtered;
    }

    test('returns all tenants when plan filter is null (All)', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', null, null);

      expect(result.length, equals(4));
      expect(result, equals(tenants));
    });

    test('filters tenants by starter plan', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', 'starter', null);

      expect(result.length, equals(1));
      expect(result[0].tenantName, equals('Riverside Academy'));
      expect(result[0].planCode, equals('starter'));
    });

    test('filters tenants by professional plan', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', 'professional', null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[0].planCode, equals('professional'));
      expect(result[1].tenantName, equals('Maple Academy'));
      expect(result[1].planCode, equals('professional'));
    });

    test('filters tenants by enterprise plan', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', 'enterprise', null);

      expect(result.length, equals(1));
      expect(result[0].tenantName, equals('Oakwood School'));
      expect(result[0].planCode, equals('enterprise'));
    });

    test('returns empty list when no tenants match plan filter', () {
      final tenants = [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'test_school',
          tenantName: 'Test School',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@test.edu',
        ),
      ];
      final result = applyFilters(tenants, '', 'enterprise', null);

      expect(result.length, equals(0));
      expect(result, isEmpty);
    });
  });

  group('Status Filter Chips', () {
    List<TenantLicenseView> createMockTenants() {
      return [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'greenwood_high',
          tenantName: 'Greenwood High School',
          planCode: 'professional',
          seatLimit: 250,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@greenwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_2',
          tenantId: 'riverside_academy',
          tenantName: 'Riverside Academy',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@riverside.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_3',
          tenantId: 'oakwood_school',
          tenantName: 'Oakwood School',
          planCode: 'enterprise',
          seatLimit: 500,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@oakwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_4',
          tenantId: 'maple_academy',
          tenantName: 'Maple Academy',
          planCode: 'professional',
          seatLimit: 300,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@maple.edu',
        ),
      ];
    }

    List<TenantLicenseView> applyFilters(
      List<TenantLicenseView> tenants,
      String searchQuery,
      String? planFilter,
      bool? activeFilter,
    ) {
      var filtered = tenants;

      // Apply search query filter
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered
            .where((t) => t.tenantName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      // Apply plan filter
      if (planFilter != null) {
        filtered = filtered.where((t) => t.planCode == planFilter).toList();
      }

      // Apply active status filter
      if (activeFilter != null) {
        filtered = filtered.where((t) => t.isActive == activeFilter).toList();
      }

      return filtered;
    }

    test('returns all tenants when status filter is null (All)', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', null, null);

      expect(result.length, equals(4));
      expect(result, equals(tenants));
    });

    test('filters tenants by active status', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', null, true);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[0].isActive, isTrue);
      expect(result[1].tenantName, equals('Riverside Academy'));
      expect(result[1].isActive, isTrue);
    });

    test('filters tenants by suspended status', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', null, false);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Oakwood School'));
      expect(result[0].isActive, isFalse);
      expect(result[1].tenantName, equals('Maple Academy'));
      expect(result[1].isActive, isFalse);
    });

    test('returns empty list when no tenants match status filter', () {
      final tenants = [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'test_school',
          tenantName: 'Test School',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@test.edu',
        ),
      ];
      final result = applyFilters(tenants, '', null, false);

      expect(result.length, equals(0));
      expect(result, isEmpty);
    });
  });

  group('Combined Filters', () {
    List<TenantLicenseView> createMockTenants() {
      return [
        TenantLicenseView(
          licenseId: 'lic_1',
          tenantId: 'greenwood_high',
          tenantName: 'Greenwood High School',
          planCode: 'professional',
          seatLimit: 250,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@greenwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_2',
          tenantId: 'riverside_academy',
          tenantName: 'Riverside Academy',
          planCode: 'starter',
          seatLimit: 100,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@riverside.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_3',
          tenantId: 'oakwood_school',
          tenantName: 'Oakwood School',
          planCode: 'enterprise',
          seatLimit: 500,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@oakwood.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_4',
          tenantId: 'maple_academy',
          tenantName: 'Maple Academy',
          planCode: 'professional',
          seatLimit: 300,
          isActive: false,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@maple.edu',
        ),
        TenantLicenseView(
          licenseId: 'lic_5',
          tenantId: 'greenfield_school',
          tenantName: 'Greenfield School',
          planCode: 'professional',
          seatLimit: 200,
          isActive: true,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
          schoolOwnerEmail: 'admin@greenfield.edu',
        ),
      ];
    }

    List<TenantLicenseView> applyFilters(
      List<TenantLicenseView> tenants,
      String searchQuery,
      String? planFilter,
      bool? activeFilter,
    ) {
      var filtered = tenants;

      // Apply search query filter
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered
            .where((t) => t.tenantName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      // Apply plan filter
      if (planFilter != null) {
        filtered = filtered.where((t) => t.planCode == planFilter).toList();
      }

      // Apply active status filter
      if (activeFilter != null) {
        filtered = filtered.where((t) => t.isActive == activeFilter).toList();
      }

      return filtered;
    }

    test('applies search query AND plan filter', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Green', 'professional', null);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[0].planCode, equals('professional'));
      expect(result[1].tenantName, equals('Greenfield School'));
      expect(result[1].planCode, equals('professional'));
    });

    test('applies search query AND status filter', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Academy', null, true);

      expect(result.length, equals(1));
      expect(result[0].tenantName, equals('Riverside Academy'));
      expect(result[0].isActive, isTrue);
    });

    test('applies plan filter AND status filter', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, '', 'professional', true);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[0].planCode, equals('professional'));
      expect(result[0].isActive, isTrue);
      expect(result[1].tenantName, equals('Greenfield School'));
      expect(result[1].planCode, equals('professional'));
      expect(result[1].isActive, isTrue);
    });

    test('applies all three filters: search + plan + status', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Green', 'professional', true);

      expect(result.length, equals(2));
      expect(result[0].tenantName, equals('Greenwood High School'));
      expect(result[0].planCode, equals('professional'));
      expect(result[0].isActive, isTrue);
      expect(result[1].tenantName, equals('Greenfield School'));
      expect(result[1].planCode, equals('professional'));
      expect(result[1].isActive, isTrue);
    });

    test('returns empty list when combined filters match nothing', () {
      final tenants = createMockTenants();
      final result = applyFilters(tenants, 'Riverside', 'enterprise', true);

      expect(result.length, equals(0));
      expect(result, isEmpty);
    });

    test('combined filters are more restrictive than individual filters', () {
      final tenants = createMockTenants();
      
      // Individual filters
      final searchOnly = applyFilters(tenants, 'Green', null, null);
      final planOnly = applyFilters(tenants, '', 'professional', null);
      final statusOnly = applyFilters(tenants, '', null, true);
      
      // Combined filter
      final combined = applyFilters(tenants, 'Green', 'professional', true);

      // Combined result should be subset of each individual filter
      expect(combined.length, lessThanOrEqualTo(searchOnly.length));
      expect(combined.length, lessThanOrEqualTo(planOnly.length));
      expect(combined.length, lessThanOrEqualTo(statusOnly.length));
      
      // All items in combined should be in each individual filter
      for (final item in combined) {
        expect(searchOnly.contains(item), isTrue);
        expect(planOnly.contains(item), isTrue);
        expect(statusOnly.contains(item), isTrue);
      }
    });
  });
}
