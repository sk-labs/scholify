import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/audit_log_service.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:drift/native.dart';
import 'dart:math';
import 'dart:convert';

/// Property-based tests for AuditLogService
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 2.2 Write property test for AuditLogService
/// 
/// This test suite validates:
/// - Property 6: Audit log append-only invariant
/// - Property 7: Audit log entry completeness
/// 
/// Requirements: H3.2, H3.3

void main() {
  late AppLocalDatabase database;
  late TenantContext tenantContext;
  late PocketbaseGateway gateway;
  late AuditLogService auditLogService;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create tenant context with test data
    tenantContext = TenantContext();
    tenantContext.setTenant(
      tenantId: 'tenant_test_001',
      tenantName: 'Test School',
      role: 'school_owner',
      isSuperAdmin: false,
    );
    
    // Create gateway with mock auth
    gateway = PocketbaseGateway(baseUrl: 'http://localhost:8090');
    
    // Mock authentication by setting a test auth model
    // Note: In production, this would be set by actual authentication
    gateway.setMockAuthModel({
      'id': 'actor_test_001',
      'email': 'test@example.com',
    });
    
    // Create audit log service
    auditLogService = AuditLogService(
      database: database,
      tenantContext: tenantContext,
      gateway: gateway,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 6: Audit log append-only invariant', () {
    /// **Validates: Requirements H3.2, H3.3**
    /// 
    /// For any sequence of write operations, the count of audit log entries
    /// SHALL be monotonically increasing (never decrease).
    test('audit log count never decreases after write operations', () async {
      const numIterations = 100;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Reset database for each iteration
        await database.delete(database.auditLogEntries).go();
        
        // Generate random sequence of write operations (1-20 operations)
        final numOperations = random.nextInt(20) + 1;
        final operations = _generateRandomOperations(random, numOperations);
        
        int previousCount = 0;
        
        for (final op in operations) {
          // Execute write operation
          await auditLogService.logWrite(
            entityType: op.entityType,
            entityId: op.entityId,
            operation: op.operation,
            changedFields: op.changedFields,
          );
          
          // Get current count
          final currentCount = await _getAuditLogCount(database);
          
          // Assert: count should never decrease
          expect(
            currentCount,
            greaterThanOrEqualTo(previousCount),
            reason: 'Audit log count decreased from $previousCount to $currentCount '
                'after operation ${op.operation} on ${op.entityType}',
          );
          
          // Assert: count should increase by exactly 1
          expect(
            currentCount,
            equals(previousCount + 1),
            reason: 'Audit log count should increase by 1 after each write operation',
          );
          
          previousCount = currentCount;
        }
      }
    });

    test('audit log count increases monotonically across multiple tenants', () async {
      const numIterations = 50;
      final random = Random(123);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Reset database
        await database.delete(database.auditLogEntries).go();
        
        // Generate random tenants (1-5 tenants)
        final numTenants = random.nextInt(5) + 1;
        final tenants = List.generate(
          numTenants,
          (i) => 'tenant_${iteration}_${i}',
        );
        
        int globalCount = 0;
        
        for (final tenantId in tenants) {
          // Switch tenant context
          tenantContext.setTenant(
            tenantId: tenantId,
            tenantName: 'Tenant $tenantId',
            role: 'school_owner',
            isSuperAdmin: false,
          );
          
          // Generate random operations for this tenant (1-10 operations)
          final numOps = random.nextInt(10) + 1;
          final operations = _generateRandomOperations(random, numOps);
          
          for (final op in operations) {
            await auditLogService.logWrite(
              entityType: op.entityType,
              entityId: op.entityId,
              operation: op.operation,
              changedFields: op.changedFields,
            );
            
            final currentCount = await _getAuditLogCount(database);
            
            expect(
              currentCount,
              equals(globalCount + 1),
              reason: 'Global audit log count should increase by 1 for each operation',
            );
            
            globalCount = currentCount;
          }
        }
      }
    });
  });

  group('Property 7: Audit log entry completeness', () {
    /// **Validates: Requirements H3.2, H3.3**
    /// 
    /// For any write operation that generates an audit log entry, the entry
    /// SHALL contain non-null values for: actorId, actorRole, entityType,
    /// entityId, operation, timestamp, and changedFields.
    test('all audit log entries contain non-null required fields', () async {
      const numIterations = 100;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Reset database
        await database.delete(database.auditLogEntries).go();
        
        // Generate random operations (1-20 operations)
        final numOperations = random.nextInt(20) + 1;
        final operations = _generateRandomOperations(random, numOperations);
        
        for (final op in operations) {
          await auditLogService.logWrite(
            entityType: op.entityType,
            entityId: op.entityId,
            operation: op.operation,
            changedFields: op.changedFields,
          );
        }
        
        // Retrieve all audit log entries
        final entries = await database.select(database.auditLogEntries).get();
        
        // Assert: all entries have non-null required fields
        for (final entry in entries) {
          expect(
            entry.actorId,
            isNotEmpty,
            reason: 'actorId must be non-null and non-empty',
          );
          
          expect(
            entry.actorRole,
            isNotEmpty,
            reason: 'actorRole must be non-null and non-empty',
          );
          
          expect(
            entry.entityType,
            isNotEmpty,
            reason: 'entityType must be non-null and non-empty',
          );
          
          expect(
            entry.entityId,
            isNotEmpty,
            reason: 'entityId must be non-null and non-empty',
          );
          
          expect(
            entry.operation,
            isNotEmpty,
            reason: 'operation must be non-null and non-empty',
          );
          
          expect(
            entry.timestamp,
            isNotNull,
            reason: 'timestamp must be non-null',
          );
          
          expect(
            entry.changedFields,
            isNotEmpty,
            reason: 'changedFields must be non-null and non-empty',
          );
          
          // Additional validation: operation must be one of create/update/delete
          expect(
            ['create', 'update', 'delete'],
            contains(entry.operation),
            reason: 'operation must be one of: create, update, delete',
          );
        }
      }
    });

    test('audit log entries contain valid JSON in changedFields', () async {
      const numIterations = 50;
      final random = Random(789);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Reset database
        await database.delete(database.auditLogEntries).go();
        
        // Generate operations with various changedFields structures
        final operations = _generateRandomOperations(random, 10);
        
        for (final op in operations) {
          await auditLogService.logWrite(
            entityType: op.entityType,
            entityId: op.entityId,
            operation: op.operation,
            changedFields: op.changedFields,
          );
        }
        
        // Retrieve all entries
        final entries = await database.select(database.auditLogEntries).get();
        
        // Assert: changedFields contains valid JSON
        for (final entry in entries) {
          expect(
            () => _parseJson(entry.changedFields),
            returnsNormally,
            reason: 'changedFields must contain valid JSON',
          );
          
          final parsed = _parseJson(entry.changedFields);
          expect(
            parsed,
            isA<Map<String, dynamic>>(),
            reason: 'changedFields JSON must be a map',
          );
        }
      }
    });

    test('audit log entries have unique IDs', () async {
      const numIterations = 50;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Reset database
        await database.delete(database.auditLogEntries).go();
        
        // Generate random operations
        final numOperations = random.nextInt(30) + 10;
        final operations = _generateRandomOperations(random, numOperations);
        
        for (final op in operations) {
          await auditLogService.logWrite(
            entityType: op.entityType,
            entityId: op.entityId,
            operation: op.operation,
            changedFields: op.changedFields,
          );
        }
        
        // Retrieve all entries
        final entries = await database.select(database.auditLogEntries).get();
        
        // Assert: all IDs are unique
        final ids = entries.map((e) => e.id).toList();
        final uniqueIds = ids.toSet();
        
        expect(
          uniqueIds.length,
          equals(ids.length),
          reason: 'All audit log entry IDs must be unique',
        );
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Represents a write operation for testing
class WriteOperation {
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> changedFields;

  WriteOperation({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.changedFields,
  });
}

/// Generates a list of random write operations
List<WriteOperation> _generateRandomOperations(Random random, int count) {
  final entityTypes = [
    'TenantRecord',
    'TenantLicenseEntry',
    'SchoolOwnerEntry',
    'TenantFeatureFlagEntry',
    'StudentEnrollmentEntry',
  ];
  
  final operations = ['create', 'update', 'delete'];
  
  return List.generate(count, (i) {
    final entityType = entityTypes[random.nextInt(entityTypes.length)];
    final operation = operations[random.nextInt(operations.length)];
    final entityId = '${entityType.toLowerCase()}_${random.nextInt(10000)}';
    
    // Generate random changed fields
    final changedFields = _generateRandomChangedFields(random, entityType);
    
    return WriteOperation(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      changedFields: changedFields,
    );
  });
}

/// Generates random changed fields based on entity type
Map<String, dynamic> _generateRandomChangedFields(Random random, String entityType) {
  final fields = <String, dynamic>{};
  
  // Add 1-5 random fields
  final numFields = random.nextInt(5) + 1;
  
  for (int i = 0; i < numFields; i++) {
    final fieldName = _generateRandomFieldName(random, entityType);
    final fieldValue = _generateRandomFieldValue(random);
    fields[fieldName] = fieldValue;
  }
  
  return fields;
}

/// Generates a random field name appropriate for the entity type
String _generateRandomFieldName(Random random, String entityType) {
  final commonFields = ['name', 'isActive', 'updatedAt', 'createdAt'];
  
  final specificFields = {
    'TenantRecord': ['tenantName', 'tenantId'],
    'TenantLicenseEntry': ['planCode', 'seatLimit', 'expiresAt'],
    'SchoolOwnerEntry': ['email', 'fullName', 'isPrimary'],
    'TenantFeatureFlagEntry': ['featureKey', 'isEnabled'],
    'StudentEnrollmentEntry': ['studentId', 'enrollmentStatus'],
  };
  
  final allFields = [
    ...commonFields,
    ...(specificFields[entityType] ?? []),
  ];
  
  return allFields[random.nextInt(allFields.length)];
}

/// Generates a random field value
dynamic _generateRandomFieldValue(Random random) {
  final valueTypes = [
    () => 'string_${random.nextInt(1000)}',
    () => random.nextInt(1000),
    () => random.nextBool(),
    () => DateTime.now().toIso8601String(),
    () => random.nextDouble() * 1000,
  ];
  
  return valueTypes[random.nextInt(valueTypes.length)]();
}

/// Gets the count of audit log entries
Future<int> _getAuditLogCount(AppLocalDatabase database) async {
  final result = await database.select(database.auditLogEntries).get();
  return result.length;
}

/// Parses JSON string
Map<String, dynamic> _parseJson(String json) {
  return Map<String, dynamic>.from(jsonDecode(json));
}
