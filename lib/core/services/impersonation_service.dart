import 'package:flutter/foundation.dart';
import '../tenant/tenant_context.dart';
import 'audit_log_service.dart';

/// Service for managing Superadmin impersonation of tenant contexts.
/// 
/// This service enables Superadmin users to temporarily adopt a tenant's context
/// for support and debugging without needing the School_Owner's credentials.
/// 
/// Requirements: Q3.2, Q3.4, Q3.6
class ImpersonationService extends ChangeNotifier {
  final TenantContext _tenantContext;
  final AuditLogService _auditLogService;

  // Original context before impersonation
  String? _originalTenantId;
  String? _originalTenantName;
  String? _originalRole;
  bool _originalIsSuperAdmin = false;

  // Impersonation state
  bool _isImpersonating = false;
  String? _impersonatedTenantId;
  String? _impersonatedTenantName;

  ImpersonationService({
    required TenantContext tenantContext,
    required AuditLogService auditLogService,
  })  : _tenantContext = tenantContext,
        _auditLogService = auditLogService;

  /// Whether impersonation is currently active.
  bool get isImpersonating => _isImpersonating;

  /// The name of the currently impersonated tenant, or null if not impersonating.
  String? get impersonatedTenantName => _impersonatedTenantName;

  /// The ID of the currently impersonated tenant, or null if not impersonating.
  String? get impersonatedTenantId => _impersonatedTenantId;

  /// Starts impersonation of the specified tenant.
  /// 
  /// Sets TenantContext to the impersonated tenant with isSuperAdmin=true,
  /// logs the impersonation start to the audit log, and notifies listeners.
  /// 
  /// Throws an exception if already impersonating another tenant.
  /// 
  /// Requirements: Q3.2, Q3.6
  Future<void> startImpersonation(String tenantId, String tenantName) async {
    if (_isImpersonating) {
      throw Exception(
        'Already impersonating tenant: $_impersonatedTenantName. '
        'End current impersonation before starting a new one.',
      );
    }

    // Save original context
    _originalTenantId = _tenantContext.tenantId;
    _originalTenantName = _tenantContext.tenantName;
    _originalRole = _tenantContext.role;
    _originalIsSuperAdmin = _tenantContext.isSuperAdmin;

    // Set impersonation state
    _isImpersonating = true;
    _impersonatedTenantId = tenantId;
    _impersonatedTenantName = tenantName;

    // Update TenantContext to impersonated tenant with isSuperAdmin=true
    _tenantContext.setTenant(
      tenantId: tenantId,
      tenantName: tenantName,
      role: 'school_owner',
      isSuperAdmin: true,
    );

    // Log impersonation start to audit log
    await _auditLogService.logWrite(
      entityType: 'impersonation',
      entityId: tenantId,
      operation: 'start',
      changedFields: {
        'impersonated_tenant_id': tenantId,
        'impersonated_tenant_name': tenantName,
      },
    );

    // Notify listeners (for UI banner updates)
    notifyListeners();
  }

  /// Ends the current impersonation session.
  /// 
  /// Restores the Superadmin's original TenantContext, logs the impersonation
  /// end to the audit log, and notifies listeners.
  /// 
  /// Throws an exception if not currently impersonating.
  /// 
  /// Requirements: Q3.4, Q3.6
  Future<void> endImpersonation() async {
    if (!_isImpersonating) {
      throw Exception('Not currently impersonating any tenant.');
    }

    final impersonatedTenantId = _impersonatedTenantId!;
    final impersonatedTenantName = _impersonatedTenantName!;

    // Log impersonation end to audit log (before clearing context)
    await _auditLogService.logWrite(
      entityType: 'impersonation',
      entityId: impersonatedTenantId,
      operation: 'end',
      changedFields: {
        'impersonated_tenant_id': impersonatedTenantId,
        'impersonated_tenant_name': impersonatedTenantName,
      },
    );

    // Restore original context
    if (_originalTenantId != null && _originalTenantName != null) {
      _tenantContext.setTenant(
        tenantId: _originalTenantId!,
        tenantName: _originalTenantName!,
        role: _originalRole ?? 'guest',
        isSuperAdmin: _originalIsSuperAdmin,
      );
    } else {
      // If original context had no tenant, clear it
      _tenantContext.clear();
      // But restore superadmin flag
      _tenantContext.setTenant(
        tenantId: '',
        tenantName: '',
        role: 'superadmin',
        isSuperAdmin: true,
      );
    }

    // Clear impersonation state
    _isImpersonating = false;
    _impersonatedTenantId = null;
    _impersonatedTenantName = null;
    _originalTenantId = null;
    _originalTenantName = null;
    _originalRole = null;
    _originalIsSuperAdmin = false;

    // Notify listeners (for UI banner updates)
    notifyListeners();
  }
}
