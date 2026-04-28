import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/csv_export_service.dart';
import 'package:drift/native.dart';
import 'package:csv/csv.dart';
import 'dart:math';

/// Property-based tests for CSVExportService
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 2.8 Write property test for CSVExportService
/// 
/// This test suite validates:
/// - Property 18: CSV serialization round-trip
/// 
/// Requirements: B4.7, Q2.6

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

  group('Property 18: CSV serialization round-trip', () {
    /// **Validates: Requirements B4.7, Q2.6**
    /// 
    /// For any list of tenant records, serializing to CSV and then parsing
    /// SHALL produce a list of records equivalent to the original (field
    /// values preserved, order may vary).
    test('CSV round-trip preserves field values for arbitrary tenant lists', () async {
      const numIterations = 100;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random tenant list (0-20 tenants)
        final numTenants = random.nextInt(21);
        final tenants = _generateRandomTenants(random, numTenants);
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Parse CSV back to records
        final parsedRecords = _parseCsvToRecords(csvContent);
        
        // Assert: parsed records count matches original (excluding header)
        expect(
          parsedRecords.length,
          equals(tenants.length),
          reason: 'Parsed record count should match original tenant count',
        );
        
        // Assert: each field value is preserved
        for (int i = 0; i < tenants.length; i++) {
          final original = tenants[i];
          final parsed = parsedRecords[i];
          
          expect(
            parsed['tenant_name'],
            equals(original.tenantName),
            reason: 'tenant_name should be preserved in round-trip',
          );
          
          expect(
            parsed['tenant_id'],
            equals(original.tenantId),
            reason: 'tenant_id should be preserved in round-trip',
          );
          
          expect(
            parsed['plan'],
            equals(original.planCode ?? ''),
            reason: 'plan should be preserved in round-trip',
          );
          
          expect(
            parsed['seat_limit'],
            equals((original.seatLimit ?? 0).toString()),
            reason: 'seat_limit should be preserved in round-trip',
          );
          
          expect(
            parsed['is_active'],
            equals(original.licenseActive == true ? 'true' : 'false'),
            reason: 'is_active should be preserved in round-trip',
          );
          
          expect(
            parsed['license_expires_at'],
            equals(original.licenseExpiresAt?.toIso8601String() ?? ''),
            reason: 'license_expires_at should be preserved in round-trip',
          );
          
          expect(
            parsed['active_students'],
            equals((original.activeStudents ?? 0).toString()),
            reason: 'active_students should be preserved in round-trip',
          );
          
          expect(
            parsed['outstanding_amount'],
            equals((original.outstandingAmount ?? 0.0).toString()),
            reason: 'outstanding_amount should be preserved in round-trip',
          );
        }
      }
    });

    test('CSV round-trip handles special characters per RFC 4180', () async {
      const numIterations = 50;
      final random = Random(123);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate tenants with special characters
        final tenants = _generateTenantsWithSpecialCharacters(random, 10);
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Parse CSV back
        final parsedRecords = _parseCsvToRecords(csvContent);
        
        // Assert: special characters are preserved
        for (int i = 0; i < tenants.length; i++) {
          final original = tenants[i];
          final parsed = parsedRecords[i];
          
          expect(
            parsed['tenant_name'],
            equals(original.tenantName),
            reason: 'Special characters in tenant_name should be preserved: "${original.tenantName}"',
          );
          
          expect(
            parsed['plan'],
            equals(original.planCode ?? ''),
            reason: 'Special characters in plan should be preserved',
          );
        }
      }
    });

    test('CSV round-trip handles Unicode characters', () async {
      const numIterations = 50;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate tenants with Unicode characters
        final tenants = _generateTenantsWithUnicode(random, 10);
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Parse CSV back
        final parsedRecords = _parseCsvToRecords(csvContent);
        
        // Assert: Unicode characters are preserved
        for (int i = 0; i < tenants.length; i++) {
          final original = tenants[i];
          final parsed = parsedRecords[i];
          
          expect(
            parsed['tenant_name'],
            equals(original.tenantName),
            reason: 'Unicode characters should be preserved: "${original.tenantName}"',
          );
        }
      }
    });

    test('CSV round-trip handles empty tenant list', () async {
      const numIterations = 10;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final tenants = <TenantUsageBillingView>[];
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Parse CSV back
        final parsedRecords = _parseCsvToRecords(csvContent);
        
        // Assert: empty list produces only header
        expect(
          parsedRecords.length,
          equals(0),
          reason: 'Empty tenant list should produce no data rows',
        );
        
        // Assert: header row is present
        expect(
          csvContent,
          contains('tenant_name'),
          reason: 'Header row should be present even for empty list',
        );
      }
    });

    test('CSV round-trip handles null values correctly', () async {
      const numIterations = 50;
      final random = Random(789);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate tenants with various null fields
        final tenants = _generateTenantsWithNulls(random, 10);
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Parse CSV back
        final parsedRecords = _parseCsvToRecords(csvContent);
        
        // Assert: null values are converted to defaults
        for (int i = 0; i < tenants.length; i++) {
          final original = tenants[i];
          final parsed = parsedRecords[i];
          
          // Null plan becomes empty string
          expect(
            parsed['plan'],
            equals(original.planCode ?? ''),
            reason: 'Null plan should become empty string',
          );
          
          // Null seat_limit becomes 0
          expect(
            parsed['seat_limit'],
            equals((original.seatLimit ?? 0).toString()),
            reason: 'Null seat_limit should become 0',
          );
          
          // Null licenseActive becomes false
          expect(
            parsed['is_active'],
            equals(original.licenseActive == true ? 'true' : 'false'),
            reason: 'Null is_active should become false',
          );
          
          // Null licenseExpiresAt becomes empty string
          expect(
            parsed['license_expires_at'],
            equals(original.licenseExpiresAt?.toIso8601String() ?? ''),
            reason: 'Null license_expires_at should become empty string',
          );
        }
      }
    });

    test('CSV serialization produces RFC 4180 compliant output', () async {
      const numIterations = 50;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate tenants with edge cases
        final tenants = _generateTenantsWithEdgeCases(random, 10);
        
        // Serialize to CSV
        final csvContent = await csvExportService.exportTenantList(tenants);
        
        // Assert: CSV can be parsed without errors
        expect(
          () => const CsvToListConverter().convert(csvContent),
          returnsNormally,
          reason: 'CSV should be parseable by standard CSV parser',
        );
        
        // Parse and verify structure
        final rows = const CsvToListConverter().convert(csvContent);
        
        // Assert: header row has correct number of columns
        expect(
          rows[0].length,
          equals(9),
          reason: 'Header row should have 9 columns',
        );
        
        // Assert: all data rows have same number of columns as header
        for (int i = 1; i < rows.length; i++) {
          expect(
            rows[i].length,
            equals(rows[0].length),
            reason: 'All rows should have same number of columns as header',
          );
        }
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a list of random tenants
List<TenantUsageBillingView> _generateRandomTenants(Random random, int count) {
  return List.generate(count, (i) {
    return TenantUsageBillingView(
      tenantId: 'tenant_${random.nextInt(100000)}',
      tenantName: _generateRandomString(random, 10, 30),
      planCode: _randomPlan(random),
      seatLimit: random.nextInt(1000) + 1,
      licenseActive: random.nextBool(),
      licenseExpiresAt: _randomDate(random),
      metricId: 'metric_${random.nextInt(100000)}',
      periodKey: '2024-${(random.nextInt(12) + 1).toString().padLeft(2, '0')}',
      activeStudents: random.nextInt(500),
      activeStaff: random.nextInt(50),
      monthlyActiveUsers: random.nextInt(550),
      storageGb: random.nextDouble() * 100,
      outstandingAmount: random.nextDouble() * 10000,
      collectedAmount: random.nextDouble() * 10000,
      overdueInvoices: random.nextInt(10),
      nextBillingAt: _randomDate(random),
      billingStatus: _randomBillingStatus(random),
      updatedAt: DateTime.now(),
    );
  });
}

/// Generates tenants with special characters (commas, quotes, newlines)
List<TenantUsageBillingView> _generateTenantsWithSpecialCharacters(Random random, int count) {
  final specialChars = [
    'School, Inc.',
    'Test "Best" School',
    'School\nWith\nNewlines',
    'School, "Quoted", Name',
    'School\tWith\tTabs',
    'School\'s Academy',
    'School & College',
    'School (Main Campus)',
    'School [Branch]',
    'School {Special}',
  ];
  
  return List.generate(count, (i) {
    return TenantUsageBillingView(
      tenantId: 'tenant_special_$i',
      tenantName: specialChars[random.nextInt(specialChars.length)],
      planCode: _randomPlan(random),
      seatLimit: random.nextInt(1000) + 1,
      licenseActive: random.nextBool(),
      licenseExpiresAt: _randomDate(random),
      metricId: 'metric_$i',
      periodKey: '2024-01',
      activeStudents: random.nextInt(500),
      activeStaff: random.nextInt(50),
      monthlyActiveUsers: random.nextInt(550),
      storageGb: random.nextDouble() * 100,
      outstandingAmount: random.nextDouble() * 10000,
      collectedAmount: random.nextDouble() * 10000,
      overdueInvoices: random.nextInt(10),
      nextBillingAt: _randomDate(random),
      billingStatus: 'current',
      updatedAt: DateTime.now(),
    );
  });
}

/// Generates tenants with Unicode characters
List<TenantUsageBillingView> _generateTenantsWithUnicode(Random random, int count) {
  final unicodeNames = [
    'École Française',
    'Schule für Kinder',
    '学校名称',
    'Школа №1',
    'مدرسة الأمل',
    'स्कूल',
    'Σχολείο',
    'בית ספר',
    '한국학교',
    'Trường học',
  ];
  
  return List.generate(count, (i) {
    return TenantUsageBillingView(
      tenantId: 'tenant_unicode_$i',
      tenantName: unicodeNames[random.nextInt(unicodeNames.length)],
      planCode: _randomPlan(random),
      seatLimit: random.nextInt(1000) + 1,
      licenseActive: random.nextBool(),
      licenseExpiresAt: _randomDate(random),
      metricId: 'metric_$i',
      periodKey: '2024-01',
      activeStudents: random.nextInt(500),
      activeStaff: random.nextInt(50),
      monthlyActiveUsers: random.nextInt(550),
      storageGb: random.nextDouble() * 100,
      outstandingAmount: random.nextDouble() * 10000,
      collectedAmount: random.nextDouble() * 10000,
      overdueInvoices: random.nextInt(10),
      nextBillingAt: _randomDate(random),
      billingStatus: 'current',
      updatedAt: DateTime.now(),
    );
  });
}

/// Generates tenants with null values
List<TenantUsageBillingView> _generateTenantsWithNulls(Random random, int count) {
  return List.generate(count, (i) {
    return TenantUsageBillingView(
      tenantId: 'tenant_null_$i',
      tenantName: 'Tenant $i',
      planCode: random.nextBool() ? null : _randomPlan(random),
      seatLimit: random.nextBool() ? null : random.nextInt(1000) + 1,
      licenseActive: random.nextBool() ? null : random.nextBool(),
      licenseExpiresAt: random.nextBool() ? null : _randomDate(random),
      metricId: random.nextBool() ? null : 'metric_$i',
      periodKey: random.nextBool() ? null : '2024-01',
      activeStudents: random.nextBool() ? null : random.nextInt(500),
      activeStaff: random.nextBool() ? null : random.nextInt(50),
      monthlyActiveUsers: random.nextBool() ? null : random.nextInt(550),
      storageGb: random.nextBool() ? null : random.nextDouble() * 100,
      outstandingAmount: random.nextBool() ? null : random.nextDouble() * 10000,
      collectedAmount: random.nextBool() ? null : random.nextDouble() * 10000,
      overdueInvoices: random.nextBool() ? null : random.nextInt(10),
      nextBillingAt: random.nextBool() ? null : _randomDate(random),
      billingStatus: random.nextBool() ? null : 'current',
      updatedAt: random.nextBool() ? null : DateTime.now(),
    );
  });
}

/// Generates tenants with edge cases
List<TenantUsageBillingView> _generateTenantsWithEdgeCases(Random random, int count) {
  final edgeCaseNames = [
    '', // Empty string
    ' ', // Single space
    '  ', // Multiple spaces
    'A', // Single character
    'A' * 100, // Very long name
    '123', // Numeric string
    '!@#\$%^&*()', // Special symbols
    '\n\r\t', // Whitespace characters
    'School, "Name", With, Commas',
    '"Quoted"',
  ];
  
  return List.generate(count, (i) {
    return TenantUsageBillingView(
      tenantId: 'tenant_edge_$i',
      tenantName: edgeCaseNames[random.nextInt(edgeCaseNames.length)],
      planCode: _randomPlan(random),
      seatLimit: random.nextInt(1000) + 1,
      licenseActive: random.nextBool(),
      licenseExpiresAt: _randomDate(random),
      metricId: 'metric_$i',
      periodKey: '2024-01',
      activeStudents: random.nextInt(500),
      activeStaff: random.nextInt(50),
      monthlyActiveUsers: random.nextInt(550),
      storageGb: random.nextDouble() * 100,
      outstandingAmount: random.nextDouble() * 10000,
      collectedAmount: random.nextDouble() * 10000,
      overdueInvoices: random.nextInt(10),
      nextBillingAt: _randomDate(random),
      billingStatus: 'current',
      updatedAt: DateTime.now(),
    );
  });
}

/// Parses CSV content to list of record maps
List<Map<String, String>> _parseCsvToRecords(String csvContent) {
  final rows = const CsvToListConverter().convert(csvContent);
  
  if (rows.isEmpty) {
    return [];
  }
  
  final headers = rows[0].map((h) => h.toString()).toList();
  final records = <Map<String, String>>[];
  
  for (int i = 1; i < rows.length; i++) {
    final record = <String, String>{};
    for (int j = 0; j < headers.length; j++) {
      record[headers[j]] = rows[i][j].toString();
    }
    records.add(record);
  }
  
  return records;
}

/// Generates a random string
String _generateRandomString(Random random, int minLength, int maxLength) {
  final length = minLength + random.nextInt(maxLength - minLength + 1);
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}

/// Returns a random plan code
String? _randomPlan(Random random) {
  final plans = ['starter', 'professional', 'enterprise', null];
  return plans[random.nextInt(plans.length)];
}

/// Returns a random date
DateTime? _randomDate(Random random) {
  if (random.nextBool()) {
    return null;
  }
  final year = 2024 + random.nextInt(2);
  final month = random.nextInt(12) + 1;
  final day = random.nextInt(28) + 1;
  return DateTime(year, month, day);
}

/// Returns a random billing status
String _randomBillingStatus(Random random) {
  final statuses = ['current', 'overdue', 'suspended'];
  return statuses[random.nextInt(statuses.length)];
}
