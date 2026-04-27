import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/seat_limit_enforcement_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'dart:math';

/// Property-based tests for SeatLimitEnforcementService
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 2.6 Write property test for SeatLimitEnforcementService
/// 
/// This test suite validates:
/// - Property 11: Seat limit enforcement boundary
/// - Property 12: Enrollment count consistency
/// 
/// Requirements: A3.2, A3.6

void main() {
  late AppLocalDatabase database;
  late SeatLimitEnforcementService service;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create seat limit enforcement service
    service = SeatLimitEnforcementService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 11: Seat limit enforcement boundary', () {
    /// **Validates: Requirements A3.2**
    /// 
    /// For any tenant with seat limit L and current active enrollment count C,
    /// a new enrollment SHALL be rejected if and only if C >= L.
    test('enrollment is rejected if and only if current count >= seat limit', () async {
      const numIterations = 100;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random seat limit (between 1 and 500)
        final seatLimit = random.nextInt(500) + 1;
        
        // Generate random current enrollment count (between 0 and seatLimit + 50)
        final currentCount = random.nextInt(seatLimit + 51);
        
        // Create tenant and license
        final tenantId = 'tenant_$iteration';
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Test School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('starter'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create current enrollments
        for (int i = 0; i < currentCount; i++) {
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Act: Check seat limit
        final shouldReject = currentCount >= seatLimit;
        
        if (shouldReject) {
          // Assert: Should throw SeatLimitExceededException
          await expectLater(
            service.checkSeatLimit(tenantId),
            throwsA(isA<SeatLimitExceededException>()),
            reason: 'Expected rejection when currentCount=$currentCount >= seatLimit=$seatLimit',
          );
        } else {
          // Assert: Should not throw
          await expectLater(
            service.checkSeatLimit(tenantId),
            completes,
            reason: 'Expected acceptance when currentCount=$currentCount < seatLimit=$seatLimit',
          );
        }
      }
    });

    test('boundary condition: exactly at limit is rejected', () async {
      const numIterations = 50;
      final random = Random(123);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random seat limit
        final seatLimit = random.nextInt(500) + 1;
        
        // Create tenant with exactly seatLimit enrollments
        final tenantId = 'tenant_boundary_$iteration';
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Boundary School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_boundary_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('professional'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create exactly seatLimit enrollments
        for (int i = 0; i < seatLimit; i++) {
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_boundary_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_boundary_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Assert: Should reject (currentCount == seatLimit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          throwsA(isA<SeatLimitExceededException>().having(
            (e) => e.currentCount,
            'currentCount',
            seatLimit,
          ).having(
            (e) => e.seatLimit,
            'seatLimit',
            seatLimit,
          )),
          reason: 'Should reject when currentCount == seatLimit ($seatLimit)',
        );
      }
    });

    test('boundary condition: one below limit is accepted', () async {
      const numIterations = 50;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random seat limit (at least 2 to test limit-1)
        final seatLimit = random.nextInt(499) + 2;
        
        // Create tenant with seatLimit-1 enrollments
        final tenantId = 'tenant_below_$iteration';
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Below Limit School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_below_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('enterprise'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create seatLimit-1 enrollments
        for (int i = 0; i < seatLimit - 1; i++) {
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_below_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_below_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Assert: Should accept (currentCount == seatLimit - 1)
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept when currentCount == seatLimit - 1 (${seatLimit - 1} < $seatLimit)',
        );
      }
    });

    test('only active enrollments count toward limit', () async {
      const numIterations = 50;
      final random = Random(789);
      
      final inactiveStatuses = ['withdrawn', 'graduated', 'suspended', 'transferred'];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final seatLimit = random.nextInt(100) + 10;
        final activeCount = random.nextInt(seatLimit);
        final inactiveCount = random.nextInt(50) + 10;
        
        // Create tenant
        final tenantId = 'tenant_mixed_$iteration';
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Mixed Status School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_mixed_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('starter'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create active enrollments
        for (int i = 0; i < activeCount; i++) {
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_active_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_active_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Create inactive enrollments with various statuses
        for (int i = 0; i < inactiveCount; i++) {
          final status = inactiveStatuses[random.nextInt(inactiveStatuses.length)];
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_inactive_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_inactive_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: Value(status),
            ),
          );
        }
        
        // Act & Assert: Only active count matters
        final shouldReject = activeCount >= seatLimit;
        
        if (shouldReject) {
          await expectLater(
            service.checkSeatLimit(tenantId),
            throwsA(isA<SeatLimitExceededException>()),
            reason: 'Should reject based on activeCount=$activeCount >= seatLimit=$seatLimit '
                '(ignoring $inactiveCount inactive enrollments)',
          );
        } else {
          await expectLater(
            service.checkSeatLimit(tenantId),
            completes,
            reason: 'Should accept based on activeCount=$activeCount < seatLimit=$seatLimit '
                '(ignoring $inactiveCount inactive enrollments)',
          );
        }
      }
    });

    test('zero or negative seat limit allows unlimited enrollments', () async {
      const numIterations = 50;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Test with seat limit 0 or negative (unlimited)
        final seatLimit = random.nextInt(3) - 1; // -1, 0, or 1 (but we'll use <= 0)
        if (seatLimit > 0) continue; // Skip positive limits for this test
        
        // Generate large enrollment count
        final enrollmentCount = random.nextInt(500) + 100;
        
        // Create tenant
        final tenantId = 'tenant_unlimited_$iteration';
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Unlimited School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_unlimited_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('enterprise'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create many enrollments
        for (int i = 0; i < enrollmentCount; i++) {
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: 'enrollment_unlimited_${iteration}_$i',
              tenantId: tenantId,
              studentId: 'student_unlimited_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Assert: Should always accept when seatLimit <= 0
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept unlimited enrollments when seatLimit=$seatLimit (unlimited)',
        );
      }
    });
  });

  group('Property 12: Enrollment count consistency', () {
    /// **Validates: Requirements A3.6**
    /// 
    /// When a student enrollment is deleted or changed to inactive status,
    /// the active enrollment count decreases accordingly so that the freed
    /// seat becomes available.
    test('deleting an active enrollment frees a seat', () async {
      const numIterations = 50;
      final random = Random(131415);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Create tenant at exactly seat limit
        final seatLimit = random.nextInt(50) + 10;
        final tenantId = 'tenant_delete_$iteration';
        
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Delete Test School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_delete_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('starter'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create exactly seatLimit enrollments
        final enrollmentIds = <String>[];
        for (int i = 0; i < seatLimit; i++) {
          final enrollmentId = 'enrollment_delete_${iteration}_$i';
          enrollmentIds.add(enrollmentId);
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: enrollmentId,
              tenantId: tenantId,
              studentId: 'student_delete_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Verify: Should reject before deletion (at limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          throwsA(isA<SeatLimitExceededException>()),
          reason: 'Should reject before deletion (at limit)',
        );
        
        // Delete one enrollment
        final enrollmentToDelete = enrollmentIds[random.nextInt(enrollmentIds.length)];
        await (database.delete(database.studentEnrollmentEntries)
              ..where((tbl) => tbl.id.equals(enrollmentToDelete)))
            .go();
        
        // Verify: Should accept after deletion (below limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept after deleting one enrollment (freed seat)',
        );
      }
    });

    test('changing enrollment status to inactive frees a seat', () async {
      const numIterations = 50;
      final random = Random(161718);
      
      final inactiveStatuses = ['withdrawn', 'graduated', 'suspended', 'transferred'];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Create tenant at exactly seat limit
        final seatLimit = random.nextInt(50) + 10;
        final tenantId = 'tenant_status_$iteration';
        
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Status Change School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_status_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('professional'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create exactly seatLimit enrollments
        final enrollmentIds = <String>[];
        for (int i = 0; i < seatLimit; i++) {
          final enrollmentId = 'enrollment_status_${iteration}_$i';
          enrollmentIds.add(enrollmentId);
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: enrollmentId,
              tenantId: tenantId,
              studentId: 'student_status_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Verify: Should reject before status change (at limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          throwsA(isA<SeatLimitExceededException>()),
          reason: 'Should reject before status change (at limit)',
        );
        
        // Change one enrollment to inactive status
        final enrollmentToChange = enrollmentIds[random.nextInt(enrollmentIds.length)];
        final newStatus = inactiveStatuses[random.nextInt(inactiveStatuses.length)];
        
        await (database.update(database.studentEnrollmentEntries)
              ..where((tbl) => tbl.id.equals(enrollmentToChange)))
            .write(StudentEnrollmentEntriesCompanion(
          enrollmentStatus: Value(newStatus),
        ));
        
        // Verify: Should accept after status change (freed seat)
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept after changing status to $newStatus (freed seat)',
        );
      }
    });

    test('multiple deletions free multiple seats', () async {
      const numIterations = 30;
      final random = Random(192021);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Create tenant exceeding seat limit
        final seatLimit = random.nextInt(30) + 20;
        final excessCount = random.nextInt(10) + 5;
        final totalEnrollments = seatLimit + excessCount;
        
        final tenantId = 'tenant_multi_delete_$iteration';
        
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Multi Delete School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_multi_delete_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('enterprise'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create enrollments exceeding limit
        final enrollmentIds = <String>[];
        for (int i = 0; i < totalEnrollments; i++) {
          final enrollmentId = 'enrollment_multi_delete_${iteration}_$i';
          enrollmentIds.add(enrollmentId);
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: enrollmentId,
              tenantId: tenantId,
              studentId: 'student_multi_delete_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Verify: Should reject (exceeding limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          throwsA(isA<SeatLimitExceededException>()),
          reason: 'Should reject when exceeding limit by $excessCount',
        );
        
        // Delete enough enrollments to go below limit
        final toDelete = excessCount + 1; // Delete excess + 1 to be below limit
        for (int i = 0; i < toDelete; i++) {
          await (database.delete(database.studentEnrollmentEntries)
                ..where((tbl) => tbl.id.equals(enrollmentIds[i])))
              .go();
        }
        
        // Verify: Should accept after deletions (below limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept after deleting $toDelete enrollments',
        );
      }
    });

    test('changing multiple enrollments to inactive frees multiple seats', () async {
      const numIterations = 30;
      final random = Random(222324);
      
      final inactiveStatuses = ['withdrawn', 'graduated', 'suspended', 'transferred'];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Create tenant exceeding seat limit
        final seatLimit = random.nextInt(30) + 20;
        final excessCount = random.nextInt(10) + 5;
        final totalEnrollments = seatLimit + excessCount;
        
        final tenantId = 'tenant_multi_status_$iteration';
        
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Multi Status School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_multi_status_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('starter'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Create enrollments exceeding limit
        final enrollmentIds = <String>[];
        for (int i = 0; i < totalEnrollments; i++) {
          final enrollmentId = 'enrollment_multi_status_${iteration}_$i';
          enrollmentIds.add(enrollmentId);
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: enrollmentId,
              tenantId: tenantId,
              studentId: 'student_multi_status_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Verify: Should reject (exceeding limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          throwsA(isA<SeatLimitExceededException>()),
          reason: 'Should reject when exceeding limit by $excessCount',
        );
        
        // Change enough enrollments to inactive to go below limit
        final toChange = excessCount + 1;
        for (int i = 0; i < toChange; i++) {
          final newStatus = inactiveStatuses[random.nextInt(inactiveStatuses.length)];
          await (database.update(database.studentEnrollmentEntries)
                ..where((tbl) => tbl.id.equals(enrollmentIds[i])))
              .write(StudentEnrollmentEntriesCompanion(
            enrollmentStatus: Value(newStatus),
          ));
        }
        
        // Verify: Should accept after status changes (below limit)
        await expectLater(
          service.checkSeatLimit(tenantId),
          completes,
          reason: 'Should accept after changing $toChange enrollments to inactive',
        );
      }
    });

    test('enrollment count consistency across mixed operations', () async {
      const numIterations = 30;
      final random = Random(252627);
      
      final inactiveStatuses = ['withdrawn', 'graduated', 'suspended', 'transferred'];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final seatLimit = random.nextInt(50) + 20;
        final tenantId = 'tenant_mixed_ops_$iteration';
        
        await database.into(database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: 'Mixed Ops School $iteration',
          ),
        );
        
        await database.into(database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: 'license_mixed_ops_$iteration',
            tenantId: tenantId,
            schoolOwnerEmail: 'owner$iteration@test.com',
            planCode: const Value('professional'),
            seatLimit: Value(seatLimit),
          ),
        );
        
        // Start with enrollments at limit
        final enrollmentIds = <String>[];
        for (int i = 0; i < seatLimit; i++) {
          final enrollmentId = 'enrollment_mixed_${iteration}_$i';
          enrollmentIds.add(enrollmentId);
          await database.into(database.studentEnrollmentEntries).insert(
            StudentEnrollmentEntriesCompanion.insert(
              id: enrollmentId,
              tenantId: tenantId,
              studentId: 'student_mixed_${iteration}_$i',
              academicSession: '2024-2025',
              enrollmentStatus: const Value('enrolled'),
            ),
          );
        }
        
        // Perform random mix of operations
        final numOperations = random.nextInt(10) + 5;
        int expectedActiveCount = seatLimit;
        
        for (int op = 0; op < numOperations; op++) {
          final operation = random.nextInt(3); // 0: delete, 1: deactivate, 2: reactivate
          
          if (operation == 0 && enrollmentIds.isNotEmpty) {
            // Delete a random enrollment
            final idx = random.nextInt(enrollmentIds.length);
            final enrollmentId = enrollmentIds[idx];
            
            // Check if it's active before deleting
            final enrollment = await (database.select(database.studentEnrollmentEntries)
                  ..where((tbl) => tbl.id.equals(enrollmentId)))
                .getSingleOrNull();
            
            if (enrollment != null) {
              await (database.delete(database.studentEnrollmentEntries)
                    ..where((tbl) => tbl.id.equals(enrollmentId)))
                  .go();
              
              if (enrollment.enrollmentStatus == 'enrolled') {
                expectedActiveCount--;
              }
              enrollmentIds.removeAt(idx);
            }
          } else if (operation == 1 && enrollmentIds.isNotEmpty) {
            // Change to inactive status
            final idx = random.nextInt(enrollmentIds.length);
            final enrollmentId = enrollmentIds[idx];
            
            final enrollment = await (database.select(database.studentEnrollmentEntries)
                  ..where((tbl) => tbl.id.equals(enrollmentId)))
                .getSingleOrNull();
            
            if (enrollment != null && enrollment.enrollmentStatus == 'enrolled') {
              final newStatus = inactiveStatuses[random.nextInt(inactiveStatuses.length)];
              await (database.update(database.studentEnrollmentEntries)
                    ..where((tbl) => tbl.id.equals(enrollmentId)))
                  .write(StudentEnrollmentEntriesCompanion(
                enrollmentStatus: Value(newStatus),
              ));
              expectedActiveCount--;
            }
          } else if (operation == 2 && enrollmentIds.isNotEmpty) {
            // Reactivate an inactive enrollment
            final idx = random.nextInt(enrollmentIds.length);
            final enrollmentId = enrollmentIds[idx];
            
            final enrollment = await (database.select(database.studentEnrollmentEntries)
                  ..where((tbl) => tbl.id.equals(enrollmentId)))
                .getSingleOrNull();
            
            if (enrollment != null && enrollment.enrollmentStatus != 'enrolled') {
              await (database.update(database.studentEnrollmentEntries)
                    ..where((tbl) => tbl.id.equals(enrollmentId)))
                  .write(const StudentEnrollmentEntriesCompanion(
                enrollmentStatus: Value('enrolled'),
              ));
              expectedActiveCount++;
            }
          }
        }
        
        // Verify: Seat limit check matches expected active count
        final shouldReject = expectedActiveCount >= seatLimit;
        
        if (shouldReject) {
          await expectLater(
            service.checkSeatLimit(tenantId),
            throwsA(isA<SeatLimitExceededException>()),
            reason: 'Should reject when expectedActiveCount=$expectedActiveCount >= seatLimit=$seatLimit',
          );
        } else {
          await expectLater(
            service.checkSeatLimit(tenantId),
            completes,
            reason: 'Should accept when expectedActiveCount=$expectedActiveCount < seatLimit=$seatLimit',
          );
        }
      }
    });
  });
}
