import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Unit tests for sync retry idempotence (task 11.5)
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A2.3
///
/// Verifies that retrying an already-synced entry does NOT create a duplicate
/// and that retryAllFailedEntries only resets entries that are genuinely failed
/// (retryCount > 0 AND status != 'synced').
void main() {
  late AppLocalDatabase database;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<int> insertEntry({
    required String entityId,
    required String status,
    required int retryCount,
  }) async {
    return database.into(database.syncQueueEntries).insert(
          SyncQueueEntriesCompanion.insert(
            tenantId: 'tenant_1',
            entityType: 'test_entity',
            entityId: entityId,
            operation: 'upsert',
            payload: '{}',
            status: Value(status),
            retryCount: Value(retryCount),
          ),
        );
  }

  Future<SyncQueueEntry?> getEntry(String entityId) async {
    return (database.select(database.syncQueueEntries)
          ..where((t) => t.entityId.equals(entityId)))
        .getSingleOrNull();
  }

  Future<int> totalEntryCount() async {
    return (await database.select(database.syncQueueEntries).get()).length;
  }

  // ── 11.5: retrying an already-synced entry does not create a duplicate ─────

  group('11.5 — Retry idempotence: already-synced entry', () {
    test('retryAllFailedEntries does not touch synced entries', () async {
      // Insert a synced entry (should be ignored by retry)
      await insertEntry(
          entityId: 'synced_1', status: 'synced', retryCount: 3);

      final countBefore = await totalEntryCount();
      await database.retryAllFailedEntries();
      final countAfter = await totalEntryCount();

      // No new rows created
      expect(countAfter, equals(countBefore));

      // The synced entry is unchanged
      final entry = await getEntry('synced_1');
      expect(entry, isNotNull);
      expect(entry!.status, equals('synced'));
      expect(entry.retryCount, equals(3)); // unchanged
    });

    test('retryAllFailedEntries does not create duplicate rows', () async {
      await insertEntry(
          entityId: 'synced_1', status: 'synced', retryCount: 2);
      await insertEntry(
          entityId: 'failed_1', status: 'failed', retryCount: 1);

      final countBefore = await totalEntryCount();
      expect(countBefore, equals(2));

      await database.retryAllFailedEntries();

      final countAfter = await totalEntryCount();
      expect(countAfter, equals(2), reason: 'No new rows must be created');
    });

    test('calling retryAllFailedEntries twice is idempotent', () async {
      await insertEntry(
          entityId: 'failed_1', status: 'failed', retryCount: 2);

      // First retry: resets to pending/retryCount=0
      await database.retryAllFailedEntries();
      final afterFirst = await getEntry('failed_1');
      expect(afterFirst!.status, equals('pending'));
      expect(afterFirst.retryCount, equals(0));

      // Second retry: nothing to reset (retryCount is already 0)
      final resetCount = await database.retryAllFailedEntries();
      expect(resetCount, equals(0),
          reason: 'Second call resets nothing — already at retryCount=0');

      final afterSecond = await getEntry('failed_1');
      expect(afterSecond!.status, equals('pending'));
      expect(afterSecond.retryCount, equals(0));
    });

    test('synced entry with high retryCount is never reset by retry', () async {
      // Simulate an entry that failed many times but eventually synced
      await insertEntry(
          entityId: 'eventually_synced', status: 'synced', retryCount: 10);

      final resetCount = await database.retryAllFailedEntries();
      expect(resetCount, equals(0));

      final entry = await getEntry('eventually_synced');
      expect(entry!.status, equals('synced'));
      expect(entry.retryCount, equals(10)); // untouched
    });

    test('only failed entries are reset, synced entries are untouched', () async {
      await insertEntry(
          entityId: 'synced_a', status: 'synced', retryCount: 5);
      await insertEntry(
          entityId: 'synced_b', status: 'synced', retryCount: 2);
      await insertEntry(
          entityId: 'failed_a', status: 'failed', retryCount: 3);
      await insertEntry(
          entityId: 'failed_b', status: 'failed', retryCount: 1);

      final resetCount = await database.retryAllFailedEntries();
      expect(resetCount, equals(2), reason: 'Only 2 failed entries reset');

      // Synced entries unchanged
      final syncedA = await getEntry('synced_a');
      final syncedB = await getEntry('synced_b');
      expect(syncedA!.status, equals('synced'));
      expect(syncedA.retryCount, equals(5));
      expect(syncedB!.status, equals('synced'));
      expect(syncedB.retryCount, equals(2));

      // Failed entries reset
      final failedA = await getEntry('failed_a');
      final failedB = await getEntry('failed_b');
      expect(failedA!.status, equals('pending'));
      expect(failedA.retryCount, equals(0));
      expect(failedB!.status, equals('pending'));
      expect(failedB.retryCount, equals(0));
    });

    test('dismissing a synced entry removes it without affecting others', () async {
      await insertEntry(
          entityId: 'synced_1', status: 'synced', retryCount: 1);
      await insertEntry(
          entityId: 'failed_1', status: 'failed', retryCount: 2);

      final syncedEntry = await getEntry('synced_1');
      final deleted = await database.dismissSyncEntry(syncedEntry!.id);
      expect(deleted, isTrue);

      // synced_1 gone, failed_1 still there
      expect(await getEntry('synced_1'), isNull);
      expect(await getEntry('failed_1'), isNotNull);
      expect(await totalEntryCount(), equals(1));
    });

    test('markSyncQueueEntrySynced sets status to synced and does not duplicate',
        () async {
      final id = await insertEntry(
          entityId: 'in_flight', status: 'pending', retryCount: 0);

      await database.markSyncQueueEntrySynced(entryId: id);

      final entry = await getEntry('in_flight');
      expect(entry!.status, equals('synced'));
      expect(await totalEntryCount(), equals(1), reason: 'No duplicate created');
    });

    test('marking same entry synced twice does not create a duplicate', () async {
      final id = await insertEntry(
          entityId: 'double_sync', status: 'pending', retryCount: 0);

      await database.markSyncQueueEntrySynced(entryId: id);
      await database.markSyncQueueEntrySynced(entryId: id); // second call

      expect(await totalEntryCount(), equals(1));
      final entry = await getEntry('double_sync');
      expect(entry!.status, equals('synced'));
    });
  });
}
