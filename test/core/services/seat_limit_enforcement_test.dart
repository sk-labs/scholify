import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/seat_limit_enforcement_service.dart';

/// Unit and integration tests for SeatLimitEnforcementService
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A3.2, A3.5, A3.6
///
/// Covers:
/// - 12.2: null/zero seatLimit allows unrestricted enrollment
/// - 12.3: freed seat becomes available after enrollment deletion
void main() {
  late AppLocalDatabase database;
  late SeatLimitEnforcementService service;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    service = SeatLimitEnforcementService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> createTenant(String tenantId, {int seatLimit = 10}) async {
    await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(id: tenantId, name: 'Test School'),
        );
    await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'lic_$tenantId',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner@test.edu',
            planCode: const Value('starter'),
            seatLimit: Value(seatLimit),
            isActive: const Value(true),
            issuedAt: Value(DateTime.now()),
            expiresAt: Value(DateTime.now().add(const Duration(days: 365))),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<String> enrollStudent(
    String tenantId,
    String studentId, {
    String status = 'enrolled',
  }) async {
    final id = 'enroll_${tenantId}_$studentId';
    await database.into(database.studentEnrollmentEntries).insert(
          StudentEnrollmentEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            studentId: studentId,
            academicSession: '2025-2026',
            enrollmentStatus: Value(status),
          ),
        );
    return id;
  }

  Future<void> deleteEnrollment(String enrollmentId) async {
    await (database.delete(database.studentEnrollmentEntries)
          ..where((t) => t.id.equals(enrollmentId)))
        .go();
  }

  // ── 12.2: null/zero seatLimit allows unrestricted enrollment ──────────────

  group('12.2 — Seat limit null/zero handling (A3.5)', () {
    test('seatLimit=0 allows enrollment regardless of active count', () async {
      await createTenant('tenant_zero', seatLimit: 0);

      // Enroll many students — should never throw
      for (var i = 1; i <= 20; i++) {
        await enrollStudent('tenant_zero', 'student_$i');
      }

      // checkSeatLimit must not throw
      await expectLater(
        service.checkSeatLimit('tenant_zero'),
        completes,
      );
    });

    test('seatLimit=0 allows enrollment even when many students are enrolled',
        () async {
      await createTenant('tenant_zero2', seatLimit: 0);

      for (var i = 1; i <= 100; i++) {
        await enrollStudent('tenant_zero2', 'student_$i');
      }

      expect(
        () => service.checkSeatLimit('tenant_zero2'),
        returnsNormally,
      );
    });

    test('seatLimit=1 allows exactly one enrollment', () async {
      await createTenant('tenant_one', seatLimit: 1);

      // First enrollment: allowed
      await expectLater(service.checkSeatLimit('tenant_one'), completes);
      await enrollStudent('tenant_one', 'student_1');

      // Second enrollment: blocked
      await expectLater(
        service.checkSeatLimit('tenant_one'),
        throwsA(isA<SeatLimitExceededException>()),
      );
    });

    test('seatLimit=0 is treated as unlimited — no exception thrown', () async {
      await createTenant('tenant_unlimited', seatLimit: 0);

      // Fill with many enrollments
      for (var i = 1; i <= 50; i++) {
        await enrollStudent('tenant_unlimited', 'student_$i');
      }

      // Must not throw
      await expectLater(
        service.checkSeatLimit('tenant_unlimited'),
        completes,
      );
    });

    test('only enrolled status counts toward seat limit', () async {
      await createTenant('tenant_status', seatLimit: 2);

      // Enroll 2 active students — at limit
      await enrollStudent('tenant_status', 'student_1', status: 'enrolled');
      await enrollStudent('tenant_status', 'student_2', status: 'enrolled');

      // These non-enrolled statuses should NOT count
      await enrollStudent('tenant_status', 'student_3', status: 'graduated');
      await enrollStudent('tenant_status', 'student_4', status: 'transferred');
      await enrollStudent('tenant_status', 'student_5', status: 'inactive');

      // At limit (2 enrolled) — next enrolled should throw
      await expectLater(
        service.checkSeatLimit('tenant_status'),
        throwsA(isA<SeatLimitExceededException>()),
      );
    });

    test('SeatLimitExceededException carries correct counts', () async {
      await createTenant('tenant_counts', seatLimit: 3);

      for (var i = 1; i <= 3; i++) {
        await enrollStudent('tenant_counts', 'student_$i');
      }

      try {
        await service.checkSeatLimit('tenant_counts');
        fail('Expected SeatLimitExceededException');
      } on SeatLimitExceededException catch (e) {
        expect(e.currentCount, equals(3));
        expect(e.seatLimit, equals(3));
      }
    });

    test('throws when no license found for tenant', () async {
      // Tenant exists but has no license
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
                id: 'no_license', name: 'No License School'),
          );

      await expectLater(
        service.checkSeatLimit('no_license'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── 12.3: freed seat becomes available after enrollment deletion ───────────

  group('12.3 — Seat count decrease on enrollment deletion (A3.6)', () {
    test('deleting an enrolled student frees a seat', () async {
      await createTenant('tenant_delete', seatLimit: 2);

      // Fill to limit
      final id1 = await enrollStudent('tenant_delete', 'student_1');
      final id2 = await enrollStudent('tenant_delete', 'student_2');

      // At limit — should throw
      await expectLater(
        service.checkSeatLimit('tenant_delete'),
        throwsA(isA<SeatLimitExceededException>()),
      );

      // Delete one enrollment
      await deleteEnrollment(id1);

      // Now one seat is free — should not throw
      await expectLater(
        service.checkSeatLimit('tenant_delete'),
        completes,
      );

      // Delete the second
      await deleteEnrollment(id2);

      // Both seats free — should not throw
      await expectLater(
        service.checkSeatLimit('tenant_delete'),
        completes,
      );
    });

    test('seat count decreases by exactly 1 per deletion', () async {
      await createTenant('tenant_count', seatLimit: 5);

      // Enroll 5 students
      final ids = <String>[];
      for (var i = 1; i <= 5; i++) {
        ids.add(await enrollStudent('tenant_count', 'student_$i'));
      }

      // At limit
      await expectLater(
        service.checkSeatLimit('tenant_count'),
        throwsA(isA<SeatLimitExceededException>()),
      );

      // Delete one by one and verify seat opens up each time
      for (var i = 0; i < 5; i++) {
        await deleteEnrollment(ids[i]);
        // After each deletion, one more seat is available
        await expectLater(service.checkSeatLimit('tenant_count'), completes);

        // Re-enroll to fill back up (except on last iteration)
        if (i < 4) {
          ids[i] = await enrollStudent('tenant_count', 'student_${i + 1}');
        }
      }
    });

    test('deleting non-enrolled status does not affect seat count', () async {
      await createTenant('tenant_nonstatus', seatLimit: 1);

      // Enroll one active student — at limit
      await enrollStudent('tenant_nonstatus', 'student_1', status: 'enrolled');

      // Add a graduated student
      final gradId = await enrollStudent(
          'tenant_nonstatus', 'student_2',
          status: 'graduated');

      // Still at limit (graduated doesn't count)
      await expectLater(
        service.checkSeatLimit('tenant_nonstatus'),
        throwsA(isA<SeatLimitExceededException>()),
      );

      // Delete the graduated student — should NOT free a seat
      await deleteEnrollment(gradId);

      // Still at limit
      await expectLater(
        service.checkSeatLimit('tenant_nonstatus'),
        throwsA(isA<SeatLimitExceededException>()),
      );
    });

    test('seat freed by deletion is immediately available for a new enrollment',
        () async {
      await createTenant('tenant_cycle', seatLimit: 1);

      // Enroll student A
      final idA = await enrollStudent('tenant_cycle', 'student_a');

      // At limit
      await expectLater(
        service.checkSeatLimit('tenant_cycle'),
        throwsA(isA<SeatLimitExceededException>()),
      );

      // Delete student A
      await deleteEnrollment(idA);

      // Seat is free — check passes
      await expectLater(service.checkSeatLimit('tenant_cycle'), completes);

      // Enroll student B in the freed seat
      await enrollStudent('tenant_cycle', 'student_b');

      // At limit again
      await expectLater(
        service.checkSeatLimit('tenant_cycle'),
        throwsA(isA<SeatLimitExceededException>()),
      );
    });

    test('multiple tenants are isolated — deleting from one does not affect another',
        () async {
      await createTenant('tenant_a', seatLimit: 1);
      await createTenant('tenant_b', seatLimit: 1);

      final idA = await enrollStudent('tenant_a', 'student_1');
      await enrollStudent('tenant_b', 'student_1');

      // Both at limit
      await expectLater(
        service.checkSeatLimit('tenant_a'),
        throwsA(isA<SeatLimitExceededException>()),
      );
      await expectLater(
        service.checkSeatLimit('tenant_b'),
        throwsA(isA<SeatLimitExceededException>()),
      );

      // Delete from tenant_a only
      await deleteEnrollment(idA);

      // tenant_a has a free seat
      await expectLater(service.checkSeatLimit('tenant_a'), completes);

      // tenant_b is still at limit
      await expectLater(
        service.checkSeatLimit('tenant_b'),
        throwsA(isA<SeatLimitExceededException>()),
      );
    });
  });
}
