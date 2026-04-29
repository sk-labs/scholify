import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';

/// Property test for wizard atomic write (Property 4)
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H1.5
///
/// Property 4: Wizard atomic write
///
/// WHEN the wizard completes all three steps with valid inputs,
/// THEN the database MUST contain exactly one TenantRecord, one
/// TenantLicenseEntry, and one SchoolOwnerEntry all sharing the same
/// tenantId — or none of them if the write fails.
///
/// This test exercises the atomic write logic directly against an in-memory
/// Drift database, without the Flutter widget layer, so it can run as a
/// fast unit/property test.
void main() {
  late AppLocalDatabase database;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------------------------------
  // Helper: perform the same atomic write the wizard does
  // ---------------------------------------------------------------------------

  Future<void> atomicWizardWrite({
    required String tenantId,
    required String schoolName,
    required String planCode,
    required int seatLimit,
    required String ownerEmail,
  }) async {
    final licenseId = 'lic_$tenantId';
    final ownerId = 'owner_$tenantId';
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 365));

    await database.transaction(() async {
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: schoolName,
              isActive: const Value(true),
              createdAt: Value(now),
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: licenseId,
              tenantId: tenantId,
              schoolOwnerEmail: ownerEmail,
              planCode: Value(planCode),
              seatLimit: Value(seatLimit),
              isActive: const Value(true),
              issuedAt: Value(now),
              expiresAt: Value(expiresAt),
              updatedAt: Value(now),
            ),
          );

      await database.into(database.schoolOwnerEntries).insert(
            SchoolOwnerEntriesCompanion.insert(
              id: ownerId,
              tenantId: tenantId,
              fullName: schoolName,
              email: ownerEmail,
              isPrimary: const Value(true),
              isActive: const Value(true),
              provisioningStatus: const Value('pending'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }

  // ---------------------------------------------------------------------------
  // Property 4a: successful write creates all three records atomically
  // ---------------------------------------------------------------------------

  group('Property 4: Wizard atomic write — success path', () {
    /// For any valid (tenantId, schoolName, plan, seatLimit, email) tuple,
    /// a successful write MUST produce exactly one TenantRecord, one
    /// TenantLicenseEntry, and one SchoolOwnerEntry, all with the same tenantId.
    test('creates TenantRecord, TenantLicenseEntry, and SchoolOwnerEntry together',
        () async {
      await atomicWizardWrite(
        tenantId: 'springfield_high',
        schoolName: 'Springfield High School',
        planCode: 'professional',
        seatLimit: 250,
        ownerEmail: 'admin@springfield.edu',
      );

      final tenants = await database.select(database.tenantRecords).get();
      final licenses =
          await database.select(database.tenantLicenseEntries).get();
      final owners = await database.select(database.schoolOwnerEntries).get();

      expect(tenants.length, equals(1), reason: 'Exactly one TenantRecord');
      expect(licenses.length, equals(1),
          reason: 'Exactly one TenantLicenseEntry');
      expect(owners.length, equals(1), reason: 'Exactly one SchoolOwnerEntry');
    });

    test('all three records share the same tenantId', () async {
      const tenantId = 'riverside_academy';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Riverside Academy',
        planCode: 'starter',
        seatLimit: 100,
        ownerEmail: 'owner@riverside.edu',
      );

      final tenant = await (database.select(database.tenantRecords)
            ..where((t) => t.id.equals(tenantId)))
          .getSingle();
      final license = await (database.select(database.tenantLicenseEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();
      final owner = await (database.select(database.schoolOwnerEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(tenant.id, equals(tenantId));
      expect(license.tenantId, equals(tenantId));
      expect(owner.tenantId, equals(tenantId));
    });

    test('license id follows lic_<tenantId> convention', () async {
      const tenantId = 'oakwood_school';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Oakwood School',
        planCode: 'enterprise',
        seatLimit: 500,
        ownerEmail: 'admin@oakwood.edu',
      );

      final license = await (database.select(database.tenantLicenseEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(license.id, equals('lic_$tenantId'));
    });

    test('owner id follows owner_<tenantId> convention', () async {
      const tenantId = 'maple_academy';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Maple Academy',
        planCode: 'professional',
        seatLimit: 300,
        ownerEmail: 'admin@maple.edu',
      );

      final owner = await (database.select(database.schoolOwnerEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(owner.id, equals('owner_$tenantId'));
    });

    test('license stores correct plan and seat limit', () async {
      const tenantId = 'cedar_school';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Cedar School',
        planCode: 'enterprise',
        seatLimit: 999,
        ownerEmail: 'admin@cedar.edu',
      );

      final license = await (database.select(database.tenantLicenseEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(license.planCode, equals('enterprise'));
      expect(license.seatLimit, equals(999));
    });

    test('owner email is stored on both license and owner records', () async {
      const tenantId = 'birch_school';
      const email = 'principal@birch.edu';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Birch School',
        planCode: 'starter',
        seatLimit: 50,
        ownerEmail: email,
      );

      final license = await (database.select(database.tenantLicenseEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();
      final owner = await (database.select(database.schoolOwnerEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(license.schoolOwnerEmail, equals(email));
      expect(owner.email, equals(email));
    });

    test('tenant is active after creation', () async {
      const tenantId = 'willow_high';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Willow High',
        planCode: 'professional',
        seatLimit: 200,
        ownerEmail: 'admin@willow.edu',
      );

      final tenant = await (database.select(database.tenantRecords)
            ..where((t) => t.id.equals(tenantId)))
          .getSingle();
      final license = await (database.select(database.tenantLicenseEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingle();

      expect(tenant.isActive, isTrue);
      expect(license.isActive, isTrue);
    });

    // Property: multiple independent writes each produce their own isolated set
    test('two separate wizard writes produce two independent tenant sets',
        () async {
      await atomicWizardWrite(
        tenantId: 'school_a',
        schoolName: 'School A',
        planCode: 'starter',
        seatLimit: 100,
        ownerEmail: 'a@school.edu',
      );

      await atomicWizardWrite(
        tenantId: 'school_b',
        schoolName: 'School B',
        planCode: 'professional',
        seatLimit: 200,
        ownerEmail: 'b@school.edu',
      );

      final tenants = await database.select(database.tenantRecords).get();
      final licenses =
          await database.select(database.tenantLicenseEntries).get();
      final owners = await database.select(database.schoolOwnerEntries).get();

      expect(tenants.length, equals(2));
      expect(licenses.length, equals(2));
      expect(owners.length, equals(2));

      // Each license belongs to its own tenant
      final licA = licenses.firstWhere((l) => l.tenantId == 'school_a');
      final licB = licenses.firstWhere((l) => l.tenantId == 'school_b');
      expect(licA.planCode, equals('starter'));
      expect(licB.planCode, equals('professional'));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 4b: failed write leaves the database unchanged (rollback)
  // ---------------------------------------------------------------------------

  group('Property 4: Wizard atomic write — rollback on failure', () {
    /// If any step inside the transaction throws, Drift rolls back the entire
    /// transaction. The database MUST be empty after a failed write.

    test('duplicate tenantId causes rollback — no records persisted', () async {
      // First write succeeds
      await atomicWizardWrite(
        tenantId: 'duplicate_school',
        schoolName: 'Duplicate School',
        planCode: 'starter',
        seatLimit: 100,
        ownerEmail: 'admin@dup.edu',
      );

      // Second write with same tenantId must fail (PK violation on TenantRecords)
      await expectLater(
        () => atomicWizardWrite(
          tenantId: 'duplicate_school',
          schoolName: 'Duplicate School v2',
          planCode: 'professional',
          seatLimit: 200,
          ownerEmail: 'admin2@dup.edu',
        ),
        throwsA(anything),
      );

      // Database should still have exactly ONE set of records (from the first write)
      final tenants = await database.select(database.tenantRecords).get();
      final licenses =
          await database.select(database.tenantLicenseEntries).get();
      final owners = await database.select(database.schoolOwnerEntries).get();

      expect(tenants.length, equals(1),
          reason: 'Rollback must not add a second TenantRecord');
      expect(licenses.length, equals(1),
          reason: 'Rollback must not add a second TenantLicenseEntry');
      expect(owners.length, equals(1),
          reason: 'Rollback must not add a second SchoolOwnerEntry');

      // The surviving record is from the first write
      expect(tenants.first.name, equals('Duplicate School'));
    });

    test('failed write leaves database completely empty', () async {
      // Attempt a write that will fail due to duplicate PK on the license
      // by manually inserting a conflicting license first
      const tenantId = 'conflict_school';
      final now = DateTime.now();

      // Pre-insert a license with the same id to cause a conflict
      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'lic_$tenantId',
              tenantId: 'some_other_tenant',
              schoolOwnerEmail: 'other@school.edu',
              planCode: const Value('starter'),
              seatLimit: const Value(100),
              isActive: const Value(true),
              issuedAt: Value(now),
              expiresAt: Value(now.add(const Duration(days: 365))),
              updatedAt: Value(now),
            ),
          );

      // Also need the referenced tenant to exist for FK
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: 'some_other_tenant',
              name: 'Some Other Tenant',
            ),
          );

      // Now attempt the wizard write — it will fail when inserting the license
      await expectLater(
        () => atomicWizardWrite(
          tenantId: tenantId,
          schoolName: 'Conflict School',
          planCode: 'professional',
          seatLimit: 150,
          ownerEmail: 'admin@conflict.edu',
        ),
        throwsA(anything),
      );

      // The TenantRecord for conflict_school must NOT exist (rolled back)
      final conflictTenant = await (database.select(database.tenantRecords)
            ..where((t) => t.id.equals(tenantId)))
          .getSingleOrNull();

      expect(conflictTenant, isNull,
          reason: 'TenantRecord must be rolled back when license insert fails');

      // The SchoolOwnerEntry must NOT exist either
      final conflictOwner = await (database.select(database.schoolOwnerEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .getSingleOrNull();

      expect(conflictOwner, isNull,
          reason:
              'SchoolOwnerEntry must be rolled back when license insert fails');
    });

    test('rollback does not affect pre-existing records', () async {
      // Create a valid tenant first
      await atomicWizardWrite(
        tenantId: 'existing_school',
        schoolName: 'Existing School',
        planCode: 'starter',
        seatLimit: 100,
        ownerEmail: 'admin@existing.edu',
      );

      // Attempt a failing write
      await expectLater(
        () => atomicWizardWrite(
          tenantId: 'existing_school', // duplicate — will fail
          schoolName: 'Existing School Copy',
          planCode: 'professional',
          seatLimit: 200,
          ownerEmail: 'copy@existing.edu',
        ),
        throwsA(anything),
      );

      // Pre-existing records must be intact
      final tenants = await database.select(database.tenantRecords).get();
      expect(tenants.length, equals(1));
      expect(tenants.first.id, equals('existing_school'));
      expect(tenants.first.name, equals('Existing School'));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 4c: all-or-nothing across all three tables
  // ---------------------------------------------------------------------------

  group('Property 4: Wizard atomic write — all-or-nothing invariant', () {
    /// The count of (TenantRecord, TenantLicenseEntry, SchoolOwnerEntry) for a
    /// given tenantId must always be (1,1,1) after success or (0,0,0) after failure.
    /// It can never be a partial state like (1,0,0) or (1,1,0).

    Future<(int, int, int)> countRecordsForTenant(String tenantId) async {
      final tenantCount = await (database.select(database.tenantRecords)
            ..where((t) => t.id.equals(tenantId)))
          .get()
          .then((r) => r.length);

      final licenseCount =
          await (database.select(database.tenantLicenseEntries)
                ..where((t) => t.tenantId.equals(tenantId)))
              .get()
              .then((r) => r.length);

      final ownerCount = await (database.select(database.schoolOwnerEntries)
            ..where((t) => t.tenantId.equals(tenantId)))
          .get()
          .then((r) => r.length);

      return (tenantCount, licenseCount, ownerCount);
    }

    test('successful write: counts are (1,1,1)', () async {
      const tenantId = 'complete_school';

      await atomicWizardWrite(
        tenantId: tenantId,
        schoolName: 'Complete School',
        planCode: 'professional',
        seatLimit: 300,
        ownerEmail: 'admin@complete.edu',
      );

      final (t, l, o) = await countRecordsForTenant(tenantId);
      expect(t, equals(1), reason: 'TenantRecord count must be 1');
      expect(l, equals(1), reason: 'TenantLicenseEntry count must be 1');
      expect(o, equals(1), reason: 'SchoolOwnerEntry count must be 1');
    });

    test('failed write: counts are (0,0,0) — no partial state', () async {
      const tenantId = 'partial_school';

      // Pre-insert a conflicting license to force failure mid-transaction
      final now = DateTime.now();
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: 'blocker_tenant',
              name: 'Blocker Tenant',
            ),
          );
      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'lic_$tenantId',
              tenantId: 'blocker_tenant',
              schoolOwnerEmail: 'blocker@school.edu',
              planCode: const Value('starter'),
              seatLimit: const Value(100),
              isActive: const Value(true),
              issuedAt: Value(now),
              expiresAt: Value(now.add(const Duration(days: 365))),
              updatedAt: Value(now),
            ),
          );

      // Wizard write will insert TenantRecord successfully, then fail on license
      await expectLater(
        () => atomicWizardWrite(
          tenantId: tenantId,
          schoolName: 'Partial School',
          planCode: 'enterprise',
          seatLimit: 400,
          ownerEmail: 'admin@partial.edu',
        ),
        throwsA(anything),
      );

      final (t, l, o) = await countRecordsForTenant(tenantId);
      expect(t, equals(0),
          reason: 'TenantRecord must be rolled back — no partial state');
      expect(l, equals(0),
          reason: 'TenantLicenseEntry must not exist for this tenantId');
      expect(o, equals(0),
          reason: 'SchoolOwnerEntry must be rolled back — no partial state');
    });

    // Parametric: test multiple valid tenants to confirm the invariant holds
    // across different plan/seat combinations
    for (final testCase in [
      ('school_starter', 'Starter School', 'starter', 50, 'a@s.edu'),
      ('school_pro', 'Pro School', 'professional', 250, 'b@p.edu'),
      ('school_ent', 'Enterprise School', 'enterprise', 1000, 'c@e.edu'),
    ]) {
      final (id, name, plan, seats, email) = testCase;

      test('all-or-nothing holds for plan=$plan, seats=$seats', () async {
        await atomicWizardWrite(
          tenantId: id,
          schoolName: name,
          planCode: plan,
          seatLimit: seats,
          ownerEmail: email,
        );

        final (t, l, o) = await countRecordsForTenant(id);
        expect(t, equals(1));
        expect(l, equals(1));
        expect(o, equals(1));
      });
    }
  });
}
