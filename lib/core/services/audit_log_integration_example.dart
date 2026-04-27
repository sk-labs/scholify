// This file demonstrates how to integrate AuditLogService with existing database operations.
// This is an example file and should not be imported in production code.

import '../database/local_database.dart';
import '../tenant/tenant_context.dart';
import '../remote/pocketbase_gateway.dart';
import 'audit_log_service.dart';

/// Example: Wrapping a tenant license update with audit logging
/// 
/// This shows how to integrate AuditLogService into existing database operations
/// to automatically log all changes.
class AuditedTenantLicenseService {
  final AppLocalDatabase _database;
  final AuditLogService _auditLogService;

  AuditedTenantLicenseService({
    required AppLocalDatabase database,
    required TenantContext tenantContext,
    required PocketbaseGateway gateway,
  })  : _database = database,
        _auditLogService = AuditLogService(
          database: database,
          tenantContext: tenantContext,
          gateway: gateway,
        );

  /// Updates a tenant license status and logs the change to the audit log.
  /// 
  /// This is an example of how to wrap existing database operations with audit logging.
  Future<void> setTenantLicenseStatusWithAudit({
    required String licenseId,
    required String tenantId,
    required bool isActive,
  }) async {
    // Perform the database update
    await _database.setTenantLicenseStatus(
      licenseId: licenseId,
      tenantId: tenantId,
      isActive: isActive,
    );

    // Log the change to the audit log
    await _auditLogService.logWrite(
      entityType: 'TenantLicenseEntry',
      entityId: licenseId,
      operation: 'update',
      changedFields: {
        'isActive': isActive,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Creates or updates a tenant license and logs the change.
  Future<void> createOrUpdateTenantLicenseWithAudit({
    required String tenantId,
    required String tenantName,
    required String schoolOwnerEmail,
    required String planCode,
    required int seatLimit,
    DateTime? expiresAt,
  }) async {
    // Determine if this is a create or update operation
    final existingLicense = await (_database.select(_database.tenantLicenseEntries)
          ..where((tbl) => tbl.tenantId.equals(tenantId)))
        .getSingleOrNull();

    final operation = existingLicense == null ? 'create' : 'update';
    final licenseId = 'lic_$tenantId';

    // Perform the database operation
    await _database.createOrUpdateTenantLicense(
      tenantId: tenantId,
      tenantName: tenantName,
      schoolOwnerEmail: schoolOwnerEmail,
      planCode: planCode,
      seatLimit: seatLimit,
      expiresAt: expiresAt,
    );

    // Log the tenant record change
    await _auditLogService.logWrite(
      entityType: 'TenantRecord',
      entityId: tenantId,
      operation: operation,
      changedFields: {
        'name': tenantName,
        'isActive': true,
      },
    );

    // Log the license change
    await _auditLogService.logWrite(
      entityType: 'TenantLicenseEntry',
      entityId: licenseId,
      operation: operation,
      changedFields: {
        'tenantId': tenantId,
        'schoolOwnerEmail': schoolOwnerEmail,
        'planCode': planCode,
        'seatLimit': seatLimit,
        'isActive': true,
        'expiresAt': expiresAt?.toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}

/// Example: How to use the audited service in a UI page
/// 
/// ```dart
/// class TenantLicensingPage extends StatefulWidget {
///   // ... widget code ...
/// }
/// 
/// class _TenantLicensingPageState extends State<TenantLicensingPage> {
///   late AuditedTenantLicenseService _auditedService;
/// 
///   @override
///   void initState() {
///     super.initState();
///     _auditedService = AuditedTenantLicenseService(
///       database: widget.database,
///       tenantContext: widget.tenantContext,
///       gateway: widget.gateway,
///     );
///   }
/// 
///   Future<void> _updateLicenseStatus(String licenseId, String tenantId, bool isActive) async {
///     try {
///       await _auditedService.setTenantLicenseStatusWithAudit(
///         licenseId: licenseId,
///         tenantId: tenantId,
///         isActive: isActive,
///       );
///       
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('License status updated and logged')),
///       );
///     } catch (e) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('Error: $e')),
///       );
///     }
///   }
/// }
/// ```
