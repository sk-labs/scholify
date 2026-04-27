import 'dart:convert';
import '../database/local_database.dart';
import '../tenant/tenant_context.dart';
import '../remote/pocketbase_gateway.dart';

/// Service for logging all significant write operations to the audit log.
/// 
/// This service intercepts write operations to auditable entities and creates
/// append-only audit log entries with actor, action, entity, and timestamp information.
/// 
/// Requirements: H3.1, H3.2
class AuditLogService {
  final AppLocalDatabase _database;
  final TenantContext _tenantContext;
  final PocketbaseGateway _gateway;
  
  static int _idCounter = 0;

  const AuditLogService({
    required AppLocalDatabase database,
    required TenantContext tenantContext,
    required PocketbaseGateway gateway,
  })  : _database = database,
        _tenantContext = tenantContext,
        _gateway = gateway;

  /// Logs a write operation to the audit log.
  /// 
  /// Captures actor information from TenantContext, generates a JSON snapshot
  /// of changed fields, writes the AuditLogEntry to Drift, and enqueues it for sync.
  /// 
  /// Parameters:
  /// - [entityType]: The type of entity being modified (e.g., 'TenantRecord', 'TenantLicenseEntry')
  /// - [entityId]: The unique identifier of the entity
  /// - [operation]: The operation type ('create', 'update', 'delete')
  /// - [changedFields]: A map of field names to their new values
  /// 
  /// Requirements: H3.1, H3.2
  Future<void> logWrite({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> changedFields,
  }) async {
    // Get actor information from TenantContext
    final tenantId = _tenantContext.tenantId ?? '';
    final actorRole = _tenantContext.role;
    
    // Get actor ID from PocketBase auth store
    final authModel = _gateway.currentAuthModelJson;
    final actorId = authModel?['id']?.toString() ?? '';

    // Validate required fields
    if (tenantId.isEmpty) {
      throw Exception('Cannot log audit entry: tenantId is required');
    }
    if (actorId.isEmpty) {
      throw Exception('Cannot log audit entry: actorId is required');
    }

    // Generate unique ID for audit log entry using timestamp + counter
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = _idCounter++;
    final auditId = 'audit_${timestamp}_${entityType}_$counter';

    // Generate JSON snapshot of changed fields
    final changedFieldsJson = jsonEncode(changedFields);

    // Write AuditLogEntry to Drift
    await _database.into(_database.auditLogEntries).insert(
      AuditLogEntriesCompanion.insert(
        id: auditId,
        tenantId: tenantId,
        actorId: actorId,
        actorRole: actorRole,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        changedFields: changedFieldsJson,
      ),
    );

    // Enqueue audit log entry for sync (push-only)
    await _database.queueOperation(
      tenantId: tenantId,
      entityType: 'audit_log',
      entityId: auditId,
      operation: 'create',
      payload: jsonEncode({
        'id': auditId,
        'tenant_id': tenantId,
        'actor_id': actorId,
        'actor_role': actorRole,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'changed_fields': changedFieldsJson,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }
}
