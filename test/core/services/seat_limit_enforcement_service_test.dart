import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/seat_limit_enforcement_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

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

  group('SeatLimitEnforcementService', () {
    test('allows enrollment when under seat limit', () async {
      // Arrange: Create tenant with seat limit of 10
      const tenantId = 'tenant_1';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_1',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('starter'),
              seatLimit: const Value(10),
            ),
          );

      // Create 5 active enrollments (under limit)
      for (int i = 0; i < 5; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Act & Assert: Should not throw
      await expectLater(
        service.checkSeatLimit(tenantId),
        completes,
      );
    });

    test('rejects enrollment when at seat limit', () async {
      // Arrange: Create tenant with seat limit of 5
      const tenantId = 'tenant_2';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 2',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_2',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('starter'),
              seatLimit: const Value(5),
            ),
          );

      // Create 5 active enrollments (at limit)
      for (int i = 0; i < 5; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Act & Assert: Should throw SeatLimitExceededException
      await expectLater(
        service.checkSeatLimit(tenantId),
        throwsA(isA<SeatLimitExceededException>().having(
          (e) => e.currentCount,
          'currentCount',
          5,
        ).having(
          (e) => e.seatLimit,
          'seatLimit',
          5,
        )),
      );
    });

    test('rejects enrollment when exceeding seat limit', () async {
      // Arrange: Create tenant with seat limit of 3
      const tenantId = 'tenant_3';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 3',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_3',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('starter'),
              seatLimit: const Value(3),
            ),
          );

      // Create 5 active enrollments (exceeding limit)
      for (int i = 0; i < 5; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Act & Assert: Should throw SeatLimitExceededException
      await expectLater(
        service.checkSeatLimit(tenantId),
        throwsA(isA<SeatLimitExceededException>().having(
          (e) => e.currentCount,
          'currentCount',
          5,
        ).having(
          (e) => e.seatLimit,
          'seatLimit',
          3,
        )),
      );
    });

    test('allows enrollment when seat limit is zero (unlimited)', () async {
      // Arrange: Create tenant with seat limit of 0 (unlimited)
      const tenantId = 'tenant_4';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 4',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_4',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('enterprise'),
              seatLimit: const Value(0), // Unlimited
            ),
          );

      // Create 100 active enrollments
      for (int i = 0; i < 100; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Act & Assert: Should not throw
      await expectLater(
        service.checkSeatLimit(tenantId),
        completes,
      );
    });

    test('only counts active enrollments (status = enrolled)', () async {
      // Arrange: Create tenant with seat limit of 10
      const tenantId = 'tenant_5';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 5',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_5',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('starter'),
              seatLimit: const Value(10),
            ),
          );

      // Create 5 active enrollments
      for (int i = 0; i < 5; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_active_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Create 10 inactive enrollments (should not count)
      for (int i = 0; i < 10; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_inactive_$i',
                tenantId: tenantId,
                studentId: 'student_inactive_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('withdrawn'),
              ),
            );
      }

      // Act & Assert: Should not throw (only 5 active, under limit of 10)
      await expectLater(
        service.checkSeatLimit(tenantId),
        completes,
      );
    });

    test('throws exception when no license found', () async {
      // Arrange: Create tenant without license
      const tenantId = 'tenant_6';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 6',
            ),
          );

      // Act & Assert: Should throw exception
      await expectLater(
        service.checkSeatLimit(tenantId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No license found for tenant'),
        )),
      );
    });

    test('boundary case: exactly at limit minus one allows enrollment',
        () async {
      // Arrange: Create tenant with seat limit of 10
      const tenantId = 'tenant_7';
      await database.into(database.tenantRecords).insert(
            TenantRecordsCompanion.insert(
              id: tenantId,
              name: 'Test School 7',
            ),
          );

      await database.into(database.tenantLicenseEntries).insert(
            TenantLicenseEntriesCompanion.insert(
              id: 'license_7',
              tenantId: tenantId,
              schoolOwnerEmail: 'owner@test.com',
              planCode: const Value('starter'),
              seatLimit: const Value(10),
            ),
          );

      // Create 9 active enrollments (limit - 1)
      for (int i = 0; i < 9; i++) {
        await database.into(database.studentEnrollmentEntries).insert(
              StudentEnrollmentEntriesCompanion.insert(
                id: 'enrollment_$i',
                tenantId: tenantId,
                studentId: 'student_$i',
                academicSession: '2024-2025',
                enrollmentStatus: const Value('enrolled'),
              ),
            );
      }

      // Act & Assert: Should not throw (9 < 10)
      await expectLater(
        service.checkSeatLimit(tenantId),
        completes,
      );
    });
  });
}
