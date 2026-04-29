import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Unit tests for sync queue retry and dismiss functionality
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A2.3, A2.4
///
/// Tests the database methods for:
/// - retryAllFailedEntries: Reset failed entries to pending state
/// - dismissSyncEntry: Delete entry from queue
void main() {
  late AppLocalDatabase database;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> createFailedSyncEntries(AppLocalDatabase db) async {
    // Create failed sync entries with different retry counts
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_123',
        operation: 'upsert',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(2),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );

    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'tenant_license',
        entityId: 'license_456',
        operation: 'upsert',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(4),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(minutes: 30))),
      ),
    );

    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'school_owner',
        entityId: 'owner_789',
        operation: 'delete',
        payload: '{}',
        status: const Value('failed'),
        retryCount: const Value(1),
        lastAttemptAt: Value(DateTime.now().subtract(const Duration(days: 1))),
      ),
    );

    // Create a synced entry (should not be affected by retry)
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_999',
        operation: 'upsert',
        payload: '{}',
        status: const Value('synced'),
        retryCount: const Value(0),
      ),
    );

    // Create a pending entry with no retries (should not be affected by retry)
    await db.into(db.syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: 'tenant_1',
        entityType: 'student_profile',
        entityId: 'student_888',
        operation: 'upsert',
        payload: '{}',
        status: const Value('pending'),
        retryCount: const Value(0),
      ),
    );
  }

  group('retryAllFailedEntries', () {
    test('resets all failed entries to pending state', () async {
      await createFailedSyncEntries(database);

      // Verify initial state: 3 failed entries
      final failedBefore = await database.getFailedSyncEntries();
      expect(failedBefore.length, 3);

      // Retry all failed entries
      final count = await database.retryAllFailedEntries();
      expect(count, 3);

      // Verify all failed entries are now pending
      final failedAfter = await database.getFailedSyncEntries();
      expect(failedAfter.length, 0);

      // Verify entries were reset to pending state
      final allEntries = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.entityId.isIn([
                  'student_123',
                  'license_456',
                  'owner_789',
                ])))
          .get();

      expect(allEntries.length, 3);
      for (final entry in allEntries) {
        expect(entry.status, 'pending');
        expect(entry.retryCount, 0);
        expect(entry.lastAttemptAt, null);
      }
    });

    test('does not affect synced entries', () async {
      await createFailedSyncEntries(database);

      // Get synced entry before retry
      final syncedBefore = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.entityId.equals('student_999')))
          .getSingle();

      expect(syncedBefore.status, 'synced');
      expect(syncedBefore.retryCount, 0);

      // Retry all failed entries
      await database.retryAllFailedEntries();

      // Verify synced entry is unchanged
      final syncedAfter = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.entityId.equals('student_999')))
          .getSingle();

      expect(syncedAfter.status, 'synced');
      expect(syncedAfter.retryCount, 0);
    });

    test('does not affect pending entries with no retries', () async {
      await createFailedSyncEntries(database);

      // Get pending entry before retry
      final pendingBefore = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.entityId.equals('student_888')))
          .getSingle();

      expect(pendingBefore.status, 'pending');
      expect(pendingBefore.retryCount, 0);

      // Retry all failed entries
      await database.retryAllFailedEntries();

      // Verify pending entry is unchanged
      final pendingAfter = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.entityId.equals('student_888')))
          .getSingle();

      expect(pendingAfter.status, 'pending');
      expect(pendingAfter.retryCount, 0);
    });

    test('returns 0 when no failed entries exist', () async {
      // No failed entries
      final count = await database.retryAllFailedEntries();
      expect(count, 0);
    });
  });

  group('dismissSyncEntry', () {
    test('deletes the specified entry from the queue', () async {
      await createFailedSyncEntries(database);

      // Get the first failed entry
      final failedEntries = await database.getFailedSyncEntries();
      expect(failedEntries.length, 3);

      final entryToDelete = failedEntries[0];

      // Dismiss the entry
      final deleted = await database.dismissSyncEntry(entryToDelete.id);
      expect(deleted, true);

      // Verify entry was deleted
      final failedAfter = await database.getFailedSyncEntries();
      expect(failedAfter.length, 2);
      expect(
        failedAfter.any((e) => e.id == entryToDelete.id),
        false,
      );
    });

    test('returns false when entry does not exist', () async {
      // Try to dismiss non-existent entry
      final deleted = await database.dismissSyncEntry(99999);
      expect(deleted, false);
    });

    test('can dismiss multiple entries individually', () async {
      await createFailedSyncEntries(database);

      final failedEntries = await database.getFailedSyncEntries();
      expect(failedEntries.length, 3);

      // Dismiss first entry
      await database.dismissSyncEntry(failedEntries[0].id);
      final afterFirst = await database.getFailedSyncEntries();
      expect(afterFirst.length, 2);

      // Dismiss second entry
      await database.dismissSyncEntry(failedEntries[1].id);
      final afterSecond = await database.getFailedSyncEntries();
      expect(afterSecond.length, 1);

      // Dismiss third entry
      await database.dismissSyncEntry(failedEntries[2].id);
      final afterThird = await database.getFailedSyncEntries();
      expect(afterThird.length, 0);
    });

    test('does not affect other entries when dismissing one', () async {
      await createFailedSyncEntries(database);

      final failedEntries = await database.getFailedSyncEntries();
      final entryToKeep1 = failedEntries[0];
      final entryToDelete = failedEntries[1];
      final entryToKeep2 = failedEntries[2];

      // Dismiss middle entry
      await database.dismissSyncEntry(entryToDelete.id);

      // Verify other entries still exist
      final remaining = await database.getFailedSyncEntries();
      expect(remaining.length, 2);
      expect(
        remaining.any((e) => e.id == entryToKeep1.id),
        true,
      );
      expect(
        remaining.any((e) => e.id == entryToKeep2.id),
        true,
      );
    });
  });
}
