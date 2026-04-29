import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Property test for sync failure warning icon invariant (Property 10)
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A2.7
///
/// Property 10: Sync failure warning icon invariant
///
/// The warning icon MUST be visible if and only if there is at least one
/// SyncQueueEntry where retryCount > 0 AND status != 'synced'.
///
/// Equivalently: watchFailedSyncEntries().isNotEmpty ↔ icon should show.
///
/// These tests verify the database query that drives the icon's visibility,
/// covering all boundary conditions and state transitions.
void main() {
  late AppLocalDatabase database;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<int> failedEntryCount() async {
    final entries = await database.getFailedSyncEntries();
    return entries.length;
  }

  Future<void> insertEntry({
    required String id,
    required String entityId,
    required String status,
    required int retryCount,
    DateTime? lastAttemptAt,
  }) async {
    await database.into(database.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'test_entity',
        entityId: entityId,
        operation: 'upsert',
        payload: '{}',
        status: Value(status),
        retryCount: Value(retryCount),
        lastAttemptAt: Value(lastAttemptAt),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Property 10a: icon hidden when queue is empty
  // ---------------------------------------------------------------------------

  group('Property 10: icon hidden when no failed entries', () {
    test('empty queue → failedEntryCount == 0 → icon hidden', () async {
      expect(await failedEntryCount(), equals(0));
    });

    test('only pending entries with retryCount=0 → icon hidden', () async {
      await insertEntry(
        id: 'e1',
        entityId: 'ent_1',
        status: 'pending',
        retryCount: 0,
      );
      await insertEntry(
        id: 'e2',
        entityId: 'ent_2',
        status: 'pending',
        retryCount: 0,
      );

      expect(await failedEntryCount(), equals(0));
    });

    test('only synced entries → icon hidden regardless of retryCount', () async {
      await insertEntry(
        id: 'e1',
        entityId: 'ent_1',
        status: 'synced',
        retryCount: 3,
      );
      await insertEntry(
        id: 'e2',
        entityId: 'ent_2',
        status: 'synced',
        retryCount: 0,
      );

      expect(await failedEntryCount(), equals(0));
    });

    test('failed entry with retryCount=0 → icon hidden', () async {
      // retryCount=0 means it has never been retried — not a "failed" entry
      await insertEntry(
        id: 'e1',
        entityId: 'ent_1',
        status: 'failed',
        retryCount: 0,
      );

      expect(await failedEntryCount(), equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 10b: icon shown when at least one failed entry exists
  // ---------------------------------------------------------------------------

  group('Property 10: icon shown when failed entries exist', () {
    test('one failed entry with retryCount=1 → failedEntryCount == 1 → icon shown',
        () async {
      await insertEntry(
        id: 'e1',
        entityId: 'ent_1',
        status: 'failed',
        retryCount: 1,
      );

      expect(await failedEntryCount(), equals(1));
    });

    test('one pending entry with retryCount > 0 → icon shown', () async {
      // A pending entry that has been retried is also a "failed" entry
      await insertEntry(
        id: 'e1',
        entityId: 'ent_1',
        status: 'pending',
        retryCount: 2,
      );

      expect(await failedEntryCount(), equals(1));
    });

    test('multiple failed entries → failedEntryCount matches', () async {
      for (var i = 1; i <= 5; i++) {
        await insertEntry(
          id: 'e$i',
          entityId: 'ent_$i',
          status: 'failed',
          retryCount: i,
        );
      }

      expect(await failedEntryCount(), equals(5));
    });

    test('mixed entries: only failed ones counted', () async {
      // Should count
      await insertEntry(
          id: 'e1', entityId: 'fail_1', status: 'failed', retryCount: 1);
      await insertEntry(
          id: 'e2', entityId: 'fail_2', status: 'failed', retryCount: 3);
      await insertEntry(
          id: 'e3', entityId: 'pending_retry', status: 'pending', retryCount: 2);

      // Should NOT count
      await insertEntry(
          id: 'e4', entityId: 'synced_1', status: 'synced', retryCount: 5);
      await insertEntry(
          id: 'e5', entityId: 'pending_fresh', status: 'pending', retryCount: 0);
      await insertEntry(
          id: 'e6', entityId: 'failed_zero', status: 'failed', retryCount: 0);

      expect(await failedEntryCount(), equals(3));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 10c: icon transitions correctly on state changes
  // ---------------------------------------------------------------------------

  group('Property 10: icon transitions on state changes', () {
    test('icon appears when first failed entry is added', () async {
      // Initially hidden
      expect(await failedEntryCount(), equals(0));

      // Add a failed entry
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);

      // Now shown
      expect(await failedEntryCount(), equals(1));
    });

    test('icon disappears when last failed entry is dismissed', () async {
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);

      // Confirm icon is shown
      expect(await failedEntryCount(), equals(1));

      // Dismiss the entry
      final entries = await database.getFailedSyncEntries();
      await database.dismissSyncEntry(entries.first.id);

      // Icon should be hidden again
      expect(await failedEntryCount(), equals(0));
    });

    test('icon disappears when all failed entries are retried (reset to pending/retryCount=0)',
        () async {
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 2);
      await insertEntry(
          id: 'e2', entityId: 'ent_2', status: 'failed', retryCount: 3);

      expect(await failedEntryCount(), equals(2));

      // Retry all — resets retryCount to 0 and status to 'pending'
      await database.retryAllFailedEntries();

      // After retry, retryCount=0 so they no longer qualify as "failed"
      expect(await failedEntryCount(), equals(0));
    });

    test('icon stays shown when some entries are dismissed but others remain',
        () async {
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);
      await insertEntry(
          id: 'e2', entityId: 'ent_2', status: 'failed', retryCount: 2);
      await insertEntry(
          id: 'e3', entityId: 'ent_3', status: 'failed', retryCount: 3);

      expect(await failedEntryCount(), equals(3));

      // Dismiss one
      final entries = await database.getFailedSyncEntries();
      await database.dismissSyncEntry(entries.first.id);

      // Still 2 remaining — icon stays shown
      expect(await failedEntryCount(), equals(2));
    });

    test('icon reappears when a retried entry fails again', () async {
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);

      // Retry all → retryCount=0, status='pending' → icon hidden
      await database.retryAllFailedEntries();
      expect(await failedEntryCount(), equals(0));

      // Simulate the sync failing again: increment retryCount
      final entries = await (database.select(database.syncQueueEntries)
            ..where((t) => t.entityId.equals('ent_1')))
          .get();
      await database.markSyncQueueEntryFailed(
        entryId: entries.first.id,
        currentRetryCount: entries.first.retryCount,
      );

      // retryCount is now 1 → icon shown again
      expect(await failedEntryCount(), equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 10d: reactive stream mirrors the invariant
  // ---------------------------------------------------------------------------

  group('Property 10: reactive stream mirrors the invariant', () {
    test('watchFailedSyncEntries emits empty list initially', () async {
      final first = await database.watchFailedSyncEntries().first;
      expect(first, isEmpty);
    });

    test('watchFailedSyncEntries emits updated list after insert', () async {
      final stream = database.watchFailedSyncEntries();

      // Confirm empty
      expect(await stream.first, isEmpty);

      // Insert a failed entry
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);

      // Stream should now emit one entry
      final entries = await stream.first;
      expect(entries.length, equals(1));
      expect(entries.first.entityId, equals('ent_1'));
    });

    test('watchFailedSyncEntries emits empty list after all entries dismissed',
        () async {
      await insertEntry(
          id: 'e1', entityId: 'ent_1', status: 'failed', retryCount: 1);

      final stream = database.watchFailedSyncEntries();
      expect((await stream.first).length, equals(1));

      // Dismiss
      final entries = await database.getFailedSyncEntries();
      await database.dismissSyncEntry(entries.first.id);

      expect(await stream.first, isEmpty);
    });
  });
}
