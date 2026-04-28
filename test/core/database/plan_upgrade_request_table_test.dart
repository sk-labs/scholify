import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

void main() {
  group('PlanUpgradeRequestEntries Table', () {
    late AppLocalDatabase database;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('creates table with correct schema', () async {
      await database.into(database.planUpgradeRequestEntries).insert(
            PlanUpgradeRequestEntriesCompanion.insert(
              id: 'req_001',
              tenantId: 'tenant_alpha',
              currentPlan: 'starter',
              requestedPlan: 'professional',
              message: const Value('Need more seats'),
              status: const Value('pending'),
            ),
          );

      final records = await database.select(database.planUpgradeRequestEntries).get();
      
      expect(records.length, 1);
      expect(records.first.id, 'req_001');
      expect(records.first.tenantId, 'tenant_alpha');
      expect(records.first.currentPlan, 'starter');
      expect(records.first.requestedPlan, 'professional');
      expect(records.first.message, 'Need more seats');
      expect(records.first.status, 'pending');
      expect(records.first.reviewedBy, isNull);
      expect(records.first.reviewedAt, isNull);
      expect(records.first.createdAt, isNotNull);
      expect(records.first.updatedAt, isNotNull);
    });

    test('supports status updates', () async {
      await database.into(database.planUpgradeRequestEntries).insert(
            PlanUpgradeRequestEntriesCompanion.insert(
              id: 'req_002',
              tenantId: 'tenant_beta',
              currentPlan: 'starter',
              requestedPlan: 'enterprise',
            ),
          );

      await (database.update(database.planUpgradeRequestEntries)
            ..where((tbl) => tbl.id.equals('req_002')))
          .write(
        PlanUpgradeRequestEntriesCompanion(
          status: const Value('approved'),
          reviewedBy: const Value('admin_001'),
          reviewedAt: Value(DateTime.now()),
        ),
      );

      final updated = await (database.select(database.planUpgradeRequestEntries)
            ..where((tbl) => tbl.id.equals('req_002')))
          .getSingle();

      expect(updated.status, 'approved');
      expect(updated.reviewedBy, 'admin_001');
      expect(updated.reviewedAt, isNotNull);
    });

    test('filters by tenant and status', () async {
      await database.batch((batch) {
        batch.insertAll(database.planUpgradeRequestEntries, [
          PlanUpgradeRequestEntriesCompanion.insert(
            id: 'req_003',
            tenantId: 'tenant_alpha',
            currentPlan: 'starter',
            requestedPlan: 'professional',
            status: const Value('pending'),
          ),
          PlanUpgradeRequestEntriesCompanion.insert(
            id: 'req_004',
            tenantId: 'tenant_alpha',
            currentPlan: 'professional',
            requestedPlan: 'enterprise',
            status: const Value('approved'),
          ),
          PlanUpgradeRequestEntriesCompanion.insert(
            id: 'req_005',
            tenantId: 'tenant_beta',
            currentPlan: 'starter',
            requestedPlan: 'professional',
            status: const Value('pending'),
          ),
        ]);
      });

      final pendingAlpha = await (database.select(database.planUpgradeRequestEntries)
            ..where((tbl) =>
                tbl.tenantId.equals('tenant_alpha') & tbl.status.equals('pending')))
          .get();

      expect(pendingAlpha.length, 1);
      expect(pendingAlpha.first.id, 'req_003');
    });

    test('orders by createdAt descending', () async {
      await database.into(database.planUpgradeRequestEntries).insert(
            PlanUpgradeRequestEntriesCompanion.insert(
              id: 'req_006',
              tenantId: 'tenant_alpha',
              currentPlan: 'starter',
              requestedPlan: 'professional',
              createdAt: Value(DateTime(2024, 1, 1)),
            ),
          );

      await database.into(database.planUpgradeRequestEntries).insert(
            PlanUpgradeRequestEntriesCompanion.insert(
              id: 'req_007',
              tenantId: 'tenant_alpha',
              currentPlan: 'starter',
              requestedPlan: 'professional',
              createdAt: Value(DateTime(2024, 1, 15)),
            ),
          );

      final ordered = await (database.select(database.planUpgradeRequestEntries)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
          .get();

      expect(ordered.first.id, 'req_007');
      expect(ordered.last.id, 'req_006');
    });
  });
}
