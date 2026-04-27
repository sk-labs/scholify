import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

void main() {
  group('TenantBrandingEntries Table', () {
    late AppLocalDatabase database;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('creates table with correct schema', () async {
      await database.into(database.tenantBrandingEntries).insert(
            TenantBrandingEntriesCompanion.insert(
              id: 'branding_001',
              tenantId: 'tenant_alpha',
              displayName: 'Alpha School',
              logoBase64: const Value('base64encodedlogo'),
            ),
          );

      final records = await database.select(database.tenantBrandingEntries).get();
      
      expect(records.length, 1);
      expect(records.first.id, 'branding_001');
      expect(records.first.tenantId, 'tenant_alpha');
      expect(records.first.displayName, 'Alpha School');
      expect(records.first.logoBase64, 'base64encodedlogo');
      expect(records.first.updatedAt, isNotNull);
    });

    test('supports nullable logoBase64', () async {
      await database.into(database.tenantBrandingEntries).insert(
            TenantBrandingEntriesCompanion.insert(
              id: 'branding_002',
              tenantId: 'tenant_beta',
              displayName: 'Beta School',
            ),
          );

      final record = await (database.select(database.tenantBrandingEntries)
            ..where((tbl) => tbl.id.equals('branding_002')))
          .getSingle();

      expect(record.logoBase64, isNull);
      expect(record.displayName, 'Beta School');
    });

    test('supports updating branding', () async {
      await database.into(database.tenantBrandingEntries).insert(
            TenantBrandingEntriesCompanion.insert(
              id: 'branding_003',
              tenantId: 'tenant_gamma',
              displayName: 'Gamma School',
            ),
          );

      await (database.update(database.tenantBrandingEntries)
            ..where((tbl) => tbl.id.equals('branding_003')))
          .write(
        TenantBrandingEntriesCompanion(
          displayName: const Value('Gamma International School'),
          logoBase64: const Value('newbase64logo'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updated = await (database.select(database.tenantBrandingEntries)
            ..where((tbl) => tbl.id.equals('branding_003')))
          .getSingle();

      expect(updated.displayName, 'Gamma International School');
      expect(updated.logoBase64, 'newbase64logo');
    });

    test('filters by tenantId', () async {
      await database.batch((batch) {
        batch.insertAll(database.tenantBrandingEntries, [
          TenantBrandingEntriesCompanion.insert(
            id: 'branding_004',
            tenantId: 'tenant_alpha',
            displayName: 'Alpha School',
          ),
          TenantBrandingEntriesCompanion.insert(
            id: 'branding_005',
            tenantId: 'tenant_beta',
            displayName: 'Beta School',
          ),
          TenantBrandingEntriesCompanion.insert(
            id: 'branding_006',
            tenantId: 'tenant_alpha',
            displayName: 'Alpha Secondary',
          ),
        ]);
      });

      final alphaRecords = await (database.select(database.tenantBrandingEntries)
            ..where((tbl) => tbl.tenantId.equals('tenant_alpha')))
          .get();

      expect(alphaRecords.length, 2);
      expect(alphaRecords.every((r) => r.tenantId == 'tenant_alpha'), isTrue);
    });

    test('supports removing logo', () async {
      await database.into(database.tenantBrandingEntries).insert(
            TenantBrandingEntriesCompanion.insert(
              id: 'branding_007',
              tenantId: 'tenant_delta',
              displayName: 'Delta School',
              logoBase64: const Value('existinglogo'),
            ),
          );

      await (database.update(database.tenantBrandingEntries)
            ..where((tbl) => tbl.id.equals('branding_007')))
          .write(
        const TenantBrandingEntriesCompanion(
          logoBase64: Value(null),
        ),
      );

      final updated = await (database.select(database.tenantBrandingEntries)
            ..where((tbl) => tbl.id.equals('branding_007')))
          .getSingle();

      expect(updated.logoBase64, isNull);
      expect(updated.displayName, 'Delta School');
    });
  });
}
