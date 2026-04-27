import 'package:drift/drift.dart';

import '../database/local_database.dart';

/// Exception thrown when a tenant attempts to enroll a student beyond their seat limit.
/// 
/// Requirements: A3.2, A3.3
class SeatLimitExceededException implements Exception {
  const SeatLimitExceededException({
    required this.currentCount,
    required this.seatLimit,
  });

  final int currentCount;
  final int seatLimit;

  @override
  String toString() =>
      'SeatLimitExceededException: Seat limit reached. Currently enrolled: $currentCount / $seatLimit seats.';
}

/// Service for enforcing seat limits defined in tenant licenses.
/// 
/// This service checks the active enrollment count against the license seat limit
/// before allowing new student enrollments. It prevents tenants from enrolling
/// more students than they have paid for.
/// 
/// Requirements: A3.1, A3.2, A3.3, A3.4, A3.5, A3.6
class SeatLimitEnforcementService {
  const SeatLimitEnforcementService({
    required AppLocalDatabase database,
  }) : _database = database;

  final AppLocalDatabase _database;

  /// Checks if a tenant can enroll a new student without exceeding their seat limit.
  /// 
  /// This method queries the count of active enrollments (where enrollmentStatus = 'enrolled')
  /// and compares it against the seat limit defined in the tenant's license.
  /// 
  /// Throws [SeatLimitExceededException] if the active enrollment count equals or exceeds
  /// the seat limit.
  /// 
  /// Parameters:
  /// - [tenantId]: The unique identifier of the tenant
  /// 
  /// Requirements: A3.1, A3.2, A3.4
  Future<void> checkSeatLimit(String tenantId) async {
    // Get the tenant's license to retrieve seat limit (A3.4)
    final license = await _getTenantLicense(tenantId);

    // If no license found, throw an error
    if (license == null) {
      throw Exception('No license found for tenant: $tenantId');
    }

    // If seat limit is null or zero, allow unlimited enrollments (A3.5)
    if (license.seatLimit <= 0) {
      return;
    }

    // Query the count of active enrollments (A3.1)
    final activeCount = await _countActiveEnrollments(tenantId);

    // Reject if active count equals or exceeds seat limit (A3.2)
    if (activeCount >= license.seatLimit) {
      throw SeatLimitExceededException(
        currentCount: activeCount,
        seatLimit: license.seatLimit,
      );
    }
  }

  /// Queries the tenant's license from the local database.
  /// 
  /// Returns null if no license is found for the tenant.
  /// 
  /// Requirements: A3.4
  Future<TenantLicenseEntry?> _getTenantLicense(String tenantId) async {
    final results = await (_database.select(_database.tenantLicenseEntries)
          ..where((tbl) => tbl.tenantId.equals(tenantId))
          ..limit(1))
        .get();

    return results.isEmpty ? null : results.first;
  }

  /// Counts the number of active student enrollments for a tenant.
  /// 
  /// An enrollment is considered "active" if its enrollmentStatus is 'enrolled'.
  /// This excludes enrollments with status like 'withdrawn', 'graduated', etc.
  /// 
  /// Requirements: A3.1, A3.6
  Future<int> _countActiveEnrollments(String tenantId) async {
    final countExpression = _database.studentEnrollmentEntries.id.count();
    final query = _database.selectOnly(_database.studentEnrollmentEntries)
      ..addColumns([countExpression])
      ..where(_database.studentEnrollmentEntries.tenantId.equals(tenantId))
      ..where(
        _database.studentEnrollmentEntries.enrollmentStatus.equals('enrolled'),
      );

    final result = await query.getSingle();
    return result.read(countExpression) ?? 0;
  }
}
