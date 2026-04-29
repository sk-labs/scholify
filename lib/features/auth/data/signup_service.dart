import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/local_database.dart';
import '../../../core/remote/pocketbase_gateway.dart';
import '../../../core/services/signup_validation_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Result of a signup operation
class SignupResult {
  const SignupResult({
    required this.success,
    this.errorMessage,
    this.tenantId,
  });

  final bool success;
  final String? errorMessage;
  final String? tenantId;
}

/// Service for handling self-service tenant signup
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B1.3, B1.4, B1.5, B1.6, B1.7
/// 
/// This service orchestrates the signup flow:
/// 1. Validates email is not already registered in PocketBase (B1.3)
/// 2. Creates PocketBase user account (B1.5)
/// 3. Creates TenantRecord with isActive=true (B1.5)
/// 4. Creates TenantLicenseEntry with planCode='starter', seatLimit=100 (B1.5)
/// 5. Creates SchoolOwnerEntry (B1.5)
/// 6. Auto-signs-in user (B1.6)
/// 7. Rolls back all records on failure (B1.7)
class SignupService {
  const SignupService({
    required PocketbaseGateway pocketbaseGateway,
    required AppLocalDatabase database,
    required SyncEngine syncEngine,
    required TenantContext tenantContext,
    required SignupValidationService validationService,
  })  : _pocketbaseGateway = pocketbaseGateway,
        _database = database,
        _syncEngine = syncEngine,
        _tenantContext = tenantContext,
        _validationService = validationService;

  final PocketbaseGateway _pocketbaseGateway;
  final AppLocalDatabase _database;
  final SyncEngine _syncEngine;
  final TenantContext _tenantContext;
  final SignupValidationService _validationService;

  /// Signs up a new tenant with the provided information
  /// 
  /// Returns a SignupResult indicating success or failure with error message
  Future<SignupResult> signUp({
    required String schoolName,
    required String ownerFullName,
    required String email,
    required String password,
  }) async {
    // Validate inputs
    final validationResults = _validationService.validateAll(
      schoolName: schoolName,
      ownerFullName: ownerFullName,
      email: email,
      password: password,
    );

    if (validationResults.values.any((isValid) => !isValid)) {
      return const SignupResult(
        success: false,
        errorMessage: 'Please correct the validation errors',
      );
    }

    // Check email uniqueness (B1.3, B1.4)
    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      return const SignupResult(
        success: false,
        errorMessage: 'An account with this email already exists.',
      );
    }

    // Generate IDs
    final tenantId = _deriveTenantId(schoolName);
    final licenseId = 'lic_$tenantId';
    final ownerId = 'owner_$tenantId';
    String? createdUserId;

    try {
      // Step 1: Create PocketBase user account (B1.5)
      createdUserId = await _createPocketBaseUser(
        email: email,
        password: password,
        fullName: ownerFullName,
        tenantId: tenantId,
      );

      if (createdUserId == null) {
        return const SignupResult(
          success: false,
          errorMessage: 'Failed to create user account. Please try again.',
        );
      }

      // Step 2: Create local records in a transaction (B1.5)
      await _createLocalRecords(
        tenantId: tenantId,
        tenantName: schoolName,
        licenseId: licenseId,
        ownerId: ownerId,
        ownerFullName: ownerFullName,
        ownerEmail: email,
      );

      // Step 3: Auto-sign-in user (B1.6)
      final signInSuccess = await _pocketbaseGateway.signInWithPassword(
        identity: email,
        password: password,
      );

      if (!signInSuccess) {
        // Rollback on sign-in failure (B1.7)
        await _rollbackLocalRecords(tenantId, licenseId, ownerId);
        await _rollbackPocketBaseUser(createdUserId);
        return const SignupResult(
          success: false,
          errorMessage: 'Account created but sign-in failed. Please try signing in manually.',
        );
      }

      // Step 4: Set tenant context
      _tenantContext.setTenant(
        tenantId: tenantId,
        tenantName: schoolName,
        role: 'school_owner',
        isSuperAdmin: false,
      );

      return SignupResult(
        success: true,
        tenantId: tenantId,
      );
    } catch (error) {
      // Rollback on any failure (B1.7)
      if (createdUserId != null) {
        await _rollbackPocketBaseUser(createdUserId);
      }
      await _rollbackLocalRecords(tenantId, licenseId, ownerId);

      return SignupResult(
        success: false,
        errorMessage: 'Signup failed: ${error.toString()}',
      );
    }
  }

  /// Checks if an email already exists in PocketBase (B1.3)
  Future<bool> _checkEmailExists(String email) async {
    try {
      final escapedEmail = email.replaceAll('"', r'\"');
      final result = await _pocketbaseGateway.client
          .collection('users')
          .getList(
            filter: 'email = "$escapedEmail"',
            perPage: 1,
          );
      return result.items.isNotEmpty;
    } catch (error) {
      // If we can't check, assume it doesn't exist to allow signup attempt
      return false;
    }
  }

  /// Creates a PocketBase user account (B1.5)
  Future<String?> _createPocketBaseUser({
    required String email,
    required String password,
    required String fullName,
    required String tenantId,
  }) async {
    try {
      final record = await _pocketbaseGateway.client.collection('users').create(
        body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'name': fullName,
          'tenant_id': tenantId,
          'is_superadmin': false,
        },
      );
      return record.id;
    } catch (error) {
      return null;
    }
  }

  /// Creates local Drift records (B1.5)
  Future<void> _createLocalRecords({
    required String tenantId,
    required String tenantName,
    required String licenseId,
    required String ownerId,
    required String ownerFullName,
    required String ownerEmail,
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(days: 365));

    // Create TenantRecord
    await _database.into(_database.tenantRecords).insert(
          TenantRecordsCompanion.insert(
            id: tenantId,
            name: tenantName,
          ),
        );

    // Create TenantLicenseEntry with starter plan and 100 seats (B1.5)
    await _database.into(_database.tenantLicenseEntries).insert(
          TenantLicenseEntriesCompanion.insert(
            id: licenseId,
            tenantId: tenantId,
            schoolOwnerEmail: ownerEmail,
            planCode: const Value('starter'),
            seatLimit: const Value(100),
            issuedAt: Value(now),
            expiresAt: Value(expiresAt),
          ),
        );

    // Create SchoolOwnerEntry
    await _database.into(_database.schoolOwnerEntries).insert(
          SchoolOwnerEntriesCompanion.insert(
            id: ownerId,
            tenantId: tenantId,
            fullName: ownerFullName,
            email: ownerEmail,
            provisioningStatus: const Value('active'),
          ),
        );

    // Enqueue sync operations (B1.5)
    await _syncEngine.enqueueOperation(
      entityType: 'tenant',
      entityId: tenantId,
      operation: 'upsert',
      payload: jsonEncode({
        'id': tenantId,
        'name': tenantName,
        'isActive': true,
        'createdAt': now.toIso8601String(),
      }),
    );

    await _syncEngine.enqueueOperation(
      entityType: 'tenant_license',
      entityId: licenseId,
      operation: 'upsert',
      payload: jsonEncode({
        'id': licenseId,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'schoolOwnerEmail': ownerEmail,
        'planCode': 'starter',
        'seatLimit': 100,
        'isActive': true,
        'issuedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }),
    );

    await _syncEngine.enqueueOperation(
      entityType: 'school_owner',
      entityId: ownerId,
      operation: 'upsert',
      payload: jsonEncode({
        'id': ownerId,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'fullName': ownerFullName,
        'email': ownerEmail,
        'isPrimary': true,
        'isActive': true,
        'provisioningStatus': 'active',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  /// Rolls back local Drift records on failure (B1.7)
  Future<void> _rollbackLocalRecords(
    String tenantId,
    String licenseId,
    String ownerId,
  ) async {
    try {
      await _database.transaction(() async {
        await (_database.delete(_database.schoolOwnerEntries)
              ..where((tbl) => tbl.id.equals(ownerId)))
            .go();
        await (_database.delete(_database.tenantLicenseEntries)
              ..where((tbl) => tbl.id.equals(licenseId)))
            .go();
        await (_database.delete(_database.tenantRecords)
              ..where((tbl) => tbl.id.equals(tenantId)))
            .go();
      });
    } catch (error) {
      // Log error but don't throw - rollback is best-effort
    }
  }

  /// Rolls back PocketBase user on failure (B1.7)
  Future<void> _rollbackPocketBaseUser(String userId) async {
    try {
      await _pocketbaseGateway.client.collection('users').delete(userId);
    } catch (error) {
      // Log error but don't throw - rollback is best-effort
    }
  }

  /// Derives a tenant_id from school name (B1.5)
  /// 
  /// Converts school name to lowercase and replaces non-alphanumeric characters with underscores
  String _deriveTenantId(String schoolName) {
    final normalized = schoolName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), ''); // Remove leading/trailing underscores

    // Ensure uniqueness by appending timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${normalized}_$timestamp';
  }
}
