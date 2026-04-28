import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/csv_export_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

void main() {
  late AppLocalDatabase database;
  late CSVExportService csvExportService;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create CSV export service
    csvExportService = CSVExportService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('CSVExportService - exportTenantList', () {
    test('returns header row only when tenant list is empty', () async {
      final tenants = <TenantUsageBillingView>[];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      expect(csv, contains('tenant_name'));
      expect(csv, contains('tenant_id'));
      expect(csv, contains('plan'));
      expect(csv, contains('seat_limit'));
      expect(csv, contains('is_active'));
      expect(csv, contains('license_expires_at'));
      expect(csv, contains('owner_email'));
      expect(csv, contains('active_students'));
      expect(csv, contains('outstanding_amount'));
      
      // Should only have one line (header)
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(1));
    });

    test('exports single tenant correctly', () async {
      // Insert a tenant and owner
      await database.into(database.tenantRecords).insert(
        TenantRecordsCompanion.insert(
          id: 'tenant_001',
          name: 'Test School',
        ),
      );
      
      await database.into(database.schoolOwnerEntries).insert(
        SchoolOwnerEntriesCompanion.insert(
          id: 'owner_001',
          tenantId: 'tenant_001',
          fullName: 'John Doe',
          email: 'john@testschool.com',
          isPrimary: const Value(true),
        ),
      );
      
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // Verify header
      expect(csv, contains('tenant_name'));
      
      // Verify data
      expect(csv, contains('Test School'));
      expect(csv, contains('tenant_001'));
      expect(csv, contains('starter'));
      expect(csv, contains('100'));
      expect(csv, contains('true'));
      expect(csv, contains('2024-12-31'));
      expect(csv, contains('john@testschool.com'));
      expect(csv, contains('50'));
      expect(csv, contains('1000.0'));
      
      // Should have two lines (header + data)
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(2));
    });

    test('exports multiple tenants correctly', () async {
      // Insert tenants and owners
      await database.into(database.tenantRecords).insert(
        TenantRecordsCompanion.insert(
          id: 'tenant_001',
          name: 'School One',
        ),
      );
      
      await database.into(database.schoolOwnerEntries).insert(
        SchoolOwnerEntriesCompanion.insert(
          id: 'owner_001',
          tenantId: 'tenant_001',
          fullName: 'Owner One',
          email: 'owner1@school.com',
          isPrimary: const Value(true),
        ),
      );
      
      await database.into(database.tenantRecords).insert(
        TenantRecordsCompanion.insert(
          id: 'tenant_002',
          name: 'School Two',
        ),
      );
      
      await database.into(database.schoolOwnerEntries).insert(
        SchoolOwnerEntriesCompanion.insert(
          id: 'owner_002',
          tenantId: 'tenant_002',
          fullName: 'Owner Two',
          email: 'owner2@school.com',
          isPrimary: const Value(true),
        ),
      );
      
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'School One',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
        TenantUsageBillingView(
          tenantId: 'tenant_002',
          tenantName: 'School Two',
          planCode: 'professional',
          seatLimit: 200,
          licenseActive: true,
          licenseExpiresAt: DateTime(2025, 6, 30),
          metricId: 'metric_002',
          periodKey: '2024-01',
          activeStudents: 150,
          activeStaff: 20,
          monthlyActiveUsers: 170,
          storageGb: 12.3,
          outstandingAmount: 2500.0,
          collectedAmount: 1500.0,
          overdueInvoices: 0,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // Verify both tenants are in the CSV
      expect(csv, contains('School One'));
      expect(csv, contains('School Two'));
      expect(csv, contains('owner1@school.com'));
      expect(csv, contains('owner2@school.com'));
      
      // Should have three lines (header + 2 data rows)
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(3));
    });

    test('handles tenant with no owner email', () async {
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // Should still generate CSV with empty owner_email field
      expect(csv, contains('Test School'));
      
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(2));
    });

    test('handles null values correctly', () async {
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test School',
          planCode: null, // null plan
          seatLimit: null, // null seat limit
          licenseActive: null, // null active status
          licenseExpiresAt: null, // null expiry
          metricId: null,
          periodKey: null,
          activeStudents: null, // null active students
          activeStaff: null,
          monthlyActiveUsers: null,
          storageGb: null,
          outstandingAmount: null, // null outstanding amount
          collectedAmount: null,
          overdueInvoices: null,
          nextBillingAt: null,
          billingStatus: null,
          updatedAt: null,
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // Should handle nulls gracefully with default values
      expect(csv, contains('Test School'));
      expect(csv, contains('tenant_001'));
      
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(2));
      
      // Check that defaults are used for null values
      final dataLine = lines[1];
      expect(dataLine, contains('0')); // Default seat_limit
      expect(dataLine, contains('false')); // Default is_active
      expect(dataLine, contains('0')); // Default active_students
      expect(dataLine, contains('0.0')); // Default outstanding_amount
    });

    test('escapes commas in tenant names per RFC 4180', () async {
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test School, Inc.',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // The csv package should wrap the field in quotes
      expect(csv, contains('"Test School, Inc."'));
    });

    test('escapes quotes in tenant names per RFC 4180', () async {
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test "Best" School',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // The csv package should escape quotes by doubling them
      expect(csv, contains('Test ""Best"" School'));
    });

    test('handles newlines in tenant names per RFC 4180', () async {
      final tenants = [
        TenantUsageBillingView(
          tenantId: 'tenant_001',
          tenantName: 'Test\nSchool',
          planCode: 'starter',
          seatLimit: 100,
          licenseActive: true,
          licenseExpiresAt: DateTime(2024, 12, 31),
          metricId: 'metric_001',
          periodKey: '2024-01',
          activeStudents: 50,
          activeStaff: 10,
          monthlyActiveUsers: 60,
          storageGb: 5.5,
          outstandingAmount: 1000.0,
          collectedAmount: 500.0,
          overdueInvoices: 2,
          nextBillingAt: DateTime(2024, 2, 1),
          billingStatus: 'current',
          updatedAt: DateTime(2024, 1, 15),
        ),
      ];
      
      final csv = await csvExportService.exportTenantList(tenants);
      
      // The csv package should wrap the field in quotes
      expect(csv, contains('"Test\nSchool"'));
    });
  });
}
