import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Database tests for audit log table operations
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H3.1, H3.2, H3.5, H3.6
///
/// Tests the audit log database methods:
/// - watchAuditLogEntries with filtering
/// - getDistinctAuditEntityTypes
/// - getDistinctAuditActorIds
void main() {
  late AppLocalDatabase database;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Audit Log Table - watchAuditLogEntries', () {
    Future<void> insertTestAuditEntries() async {
      final now = DateTime.now();
      
      await database.batch((batch) {
        batch.insertAll(database.auditLogEntries, [
          AuditLogEntriesCompanion.insert(
            id: 'audit_1',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_1',
            operation: 'create',
            changedFields: '{"name": "Test School"}',
            timestamp: Value(now.subtract(const Duration(hours: 1))),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_2',
            tenantId: 'tenant_1',
            actorId: 'user_2',
            actorRole: 'school_owner',
            entityType: 'License',
            entityId: 'license_1',
            operation: 'update',
            changedFields: '{"seatLimit": 200}',
            timestamp: Value(now.subtract(const Duration(hours: 2))),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_3',
            tenantId: 'tenant_2',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_2',
            operation: 'create',
            changedFields: '{"name": "Another School"}',
            timestamp: Value(now.subtract(const Duration(hours: 3))),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_4',
            tenantId: 'tenant_1',
            actorId: 'user_3',
            actorRole: 'school_owner',
            entityType: 'Enrollment',
            entityId: 'enrollment_1',
            operation: 'create',
            changedFields: '{"studentId": "student_1"}',
            timestamp: Value(now.subtract(const Duration(hours: 4))),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_5',
            tenantId: 'tenant_2',
            actorId: 'user_2',
            actorRole: 'school_owner',
            entityType: 'License',
            entityId: 'license_2',
            operation: 'delete',
            changedFields: '{}',
            timestamp: Value(now.subtract(const Duration(hours: 5))),
          ),
        ]);
      });
    }

    test('returns all entries when no filters are applied', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries().first;

      expect(entries.length, equals(5));
    });

    test('filters entries by entity type - Tenant', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'Tenant',
      ).first;

      expect(entries.length, equals(2));
      expect(entries.every((e) => e.entityType == 'Tenant'), isTrue);
    });

    test('filters entries by entity type - License', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'License',
      ).first;

      expect(entries.length, equals(2));
      expect(entries.every((e) => e.entityType == 'License'), isTrue);
    });

    test('filters entries by entity type - Enrollment', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'Enrollment',
      ).first;

      expect(entries.length, equals(1));
      expect(entries[0].entityType, equals('Enrollment'));
    });

    test('returns empty list when entity type has no matches', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'NonExistentType',
      ).first;

      expect(entries, isEmpty);
    });

    test('filters entries by actor ID - user_1', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        actorIdFilter: 'user_1',
      ).first;

      expect(entries.length, equals(2));
      expect(entries.every((e) => e.actorId == 'user_1'), isTrue);
    });

    test('filters entries by actor ID - user_2', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        actorIdFilter: 'user_2',
      ).first;

      expect(entries.length, equals(2));
      expect(entries.every((e) => e.actorId == 'user_2'), isTrue);
    });

    test('returns empty list when actor ID has no matches', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        actorIdFilter: 'nonexistent_user',
      ).first;

      expect(entries, isEmpty);
    });

    test('applies both entity type and actor filters (combined)', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'Tenant',
        actorIdFilter: 'user_1',
      ).first;

      expect(entries.length, equals(2));
      expect(entries.every((e) => e.entityType == 'Tenant' && e.actorId == 'user_1'), isTrue);
    });

    test('combined filters return empty when no matches', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        entityTypeFilter: 'Enrollment',
        actorIdFilter: 'user_1',
      ).first;

      expect(entries, isEmpty);
    });

    test('respects limit parameter', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries(
        limit: 2,
      ).first;

      expect(entries.length, equals(2));
    });

    test('respects offset parameter', () async {
      await insertTestAuditEntries();

      final firstPage = await database.watchAuditLogEntries(
        limit: 2,
        offset: 0,
      ).first;

      final secondPage = await database.watchAuditLogEntries(
        limit: 2,
        offset: 2,
      ).first;

      expect(firstPage.length, equals(2));
      expect(secondPage.length, equals(2));
      expect(firstPage[0].id, isNot(equals(secondPage[0].id)));
    });

    test('orders entries by timestamp descending', () async {
      await insertTestAuditEntries();

      final entries = await database.watchAuditLogEntries().first;

      // Verify entries are in descending order by timestamp
      for (int i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].timestamp.isAfter(entries[i + 1].timestamp) ||
          entries[i].timestamp.isAtSameMomentAs(entries[i + 1].timestamp),
          isTrue,
          reason: 'Entries should be ordered by timestamp descending',
        );
      }
    });
  });

  group('Audit Log Table - getDistinctAuditEntityTypes', () {
    test('returns empty list when no audit entries exist', () async {
      final entityTypes = await database.getDistinctAuditEntityTypes();

      expect(entityTypes, isEmpty);
    });

    test('returns distinct entity types', () async {
      final now = DateTime.now();
      
      await database.batch((batch) {
        batch.insertAll(database.auditLogEntries, [
          AuditLogEntriesCompanion.insert(
            id: 'audit_1',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_2',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'License',
            entityId: 'license_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_3',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_2',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
        ]);
      });

      final entityTypes = await database.getDistinctAuditEntityTypes();

      expect(entityTypes.length, equals(2));
      expect(entityTypes, containsAll(['Tenant', 'License']));
    });

    test('returns entity types in alphabetical order', () async {
      final now = DateTime.now();
      
      await database.batch((batch) {
        batch.insertAll(database.auditLogEntries, [
          AuditLogEntriesCompanion.insert(
            id: 'audit_1',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_2',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Enrollment',
            entityId: 'enrollment_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_3',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'License',
            entityId: 'license_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
        ]);
      });

      final entityTypes = await database.getDistinctAuditEntityTypes();

      expect(entityTypes, equals(['Enrollment', 'License', 'Tenant']));
    });
  });

  group('Audit Log Table - getDistinctAuditActorIds', () {
    test('returns empty list when no audit entries exist', () async {
      final actorIds = await database.getDistinctAuditActorIds();

      expect(actorIds, isEmpty);
    });

    test('returns distinct actor IDs', () async {
      final now = DateTime.now();
      
      await database.batch((batch) {
        batch.insertAll(database.auditLogEntries, [
          AuditLogEntriesCompanion.insert(
            id: 'audit_1',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_2',
            tenantId: 'tenant_1',
            actorId: 'user_2',
            actorRole: 'school_owner',
            entityType: 'License',
            entityId: 'license_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_3',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_2',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
        ]);
      });

      final actorIds = await database.getDistinctAuditActorIds();

      expect(actorIds.length, equals(2));
      expect(actorIds, containsAll(['user_1', 'user_2']));
    });

    test('returns actor IDs in alphabetical order', () async {
      final now = DateTime.now();
      
      await database.batch((batch) {
        batch.insertAll(database.auditLogEntries, [
          AuditLogEntriesCompanion.insert(
            id: 'audit_1',
            tenantId: 'tenant_1',
            actorId: 'user_3',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_2',
            tenantId: 'tenant_1',
            actorId: 'user_1',
            actorRole: 'school_owner',
            entityType: 'License',
            entityId: 'license_1',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
          AuditLogEntriesCompanion.insert(
            id: 'audit_3',
            tenantId: 'tenant_1',
            actorId: 'user_2',
            actorRole: 'superadmin',
            entityType: 'Tenant',
            entityId: 'tenant_2',
            operation: 'create',
            changedFields: '{}',
            timestamp: Value(now),
          ),
        ]);
      });

      final actorIds = await database.getDistinctAuditActorIds();

      expect(actorIds, equals(['user_1', 'user_2', 'user_3']));
    });
  });
}
