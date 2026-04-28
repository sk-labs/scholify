# ImpersonationService

## Overview

The `ImpersonationService` enables Superadmin users to temporarily adopt a tenant's context for support and debugging purposes without needing the School_Owner's credentials. This service manages TenantContext state transitions, logs all impersonation events to the audit log, and provides reactive state for UI banner display.

## Requirements

- **Q3.2**: Set TenantContext to impersonated tenant with `isSuperAdmin=true`
- **Q3.4**: Restore original TenantContext when impersonation ends
- **Q3.6**: Log impersonation start/end to audit log

## Usage

### Basic Setup

```dart
final impersonationService = ImpersonationService(
  tenantContext: tenantContext,
  auditLogService: auditLogService,
);
```

### Starting Impersonation

```dart
// Start impersonating a tenant
await impersonationService.startImpersonation(
  'tenant_001',
  'Test School',
);

// Check if impersonating
if (impersonationService.isImpersonating) {
  print('Impersonating: ${impersonationService.impersonatedTenantName}');
}
```

### Ending Impersonation

```dart
// End impersonation and restore original context
await impersonationService.endImpersonation();
```

### Listening to State Changes

The service extends `ChangeNotifier`, so you can listen for state changes:

```dart
impersonationService.addListener(() {
  if (impersonationService.isImpersonating) {
    // Show impersonation banner
    showBanner(impersonationService.impersonatedTenantName);
  } else {
    // Hide impersonation banner
    hideBanner();
  }
});
```

### UI Integration Example

```dart
Widget buildImpersonationBanner(BuildContext context) {
  return ListenableBuilder(
    listenable: impersonationService,
    builder: (context, child) {
      if (!impersonationService.isImpersonating) {
        return SizedBox.shrink();
      }
      
      return MaterialBanner(
        content: Text(
          'Impersonating: ${impersonationService.impersonatedTenantName}',
        ),
        actions: [
          TextButton(
            onPressed: () => impersonationService.endImpersonation(),
            child: Text('Exit'),
          ),
        ],
      );
    },
  );
}
```

## Public API

### Properties

- `bool get isImpersonating`: Whether impersonation is currently active
- `String? get impersonatedTenantName`: Name of the impersonated tenant (null if not impersonating)
- `String? get impersonatedTenantId`: ID of the impersonated tenant (null if not impersonating)

### Methods

- `Future<void> startImpersonation(String tenantId, String tenantName)`: Start impersonating a tenant
- `Future<void> endImpersonation()`: End the current impersonation session

## Behavior

### Starting Impersonation

When `startImpersonation()` is called:

1. Saves the current TenantContext state (original context)
2. Updates the impersonation state flags
3. Sets TenantContext to the impersonated tenant with:
   - `tenantId`: The impersonated tenant's ID
   - `tenantName`: The impersonated tenant's name
   - `role`: `'school_owner'`
   - `isSuperAdmin`: `true` (preserves elevated privileges)
4. Logs the impersonation start event to the audit log
5. Notifies listeners of the state change

### Ending Impersonation

When `endImpersonation()` is called:

1. Logs the impersonation end event to the audit log
2. Restores the original TenantContext state
3. Clears the impersonation state flags
4. Notifies listeners of the state change

### Context Restoration

The service intelligently handles context restoration:

- If the original context had a tenant, it restores that tenant
- If the original context had no tenant (Superadmin with no tenant selected), it restores the Superadmin context with no tenant

## Error Handling

### Nested Impersonation Prevention

The service prevents nested impersonation. If you attempt to start impersonation while already impersonating, it throws an exception:

```dart
try {
  await impersonationService.startImpersonation('tenant_001', 'School 1');
  await impersonationService.startImpersonation('tenant_002', 'School 2'); // Throws!
} catch (e) {
  print(e); // "Already impersonating tenant: School 1. End current impersonation before starting a new one."
}
```

### Invalid End Impersonation

If you attempt to end impersonation when not currently impersonating, it throws an exception:

```dart
try {
  await impersonationService.endImpersonation(); // Throws if not impersonating!
} catch (e) {
  print(e); // "Not currently impersonating any tenant."
}
```

## Audit Logging

All impersonation events are logged to the audit log with:

- **Entity Type**: `'impersonation'`
- **Entity ID**: The impersonated tenant's ID
- **Operation**: `'start'` or `'end'`
- **Changed Fields**: JSON object containing:
  - `impersonated_tenant_id`: The tenant ID
  - `impersonated_tenant_name`: The tenant name

Example audit log entry:

```json
{
  "id": "audit_1234567890_impersonation_0",
  "tenant_id": "tenant_001",
  "actor_id": "superadmin_001",
  "actor_role": "superadmin",
  "entity_type": "impersonation",
  "entity_id": "tenant_001",
  "operation": "start",
  "changed_fields": "{\"impersonated_tenant_id\":\"tenant_001\",\"impersonated_tenant_name\":\"Test School\"}",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## Testing

The service includes comprehensive unit tests covering:

- Initial state verification
- State transitions (start/end impersonation)
- TenantContext updates
- Context preservation and restoration
- Multiple impersonation cycles
- Listener notifications
- Error conditions (nested impersonation, invalid end)
- Edge cases (empty names, special characters, long names)

Run tests with:

```bash
flutter test test/core/services/impersonation_service_test.dart
```

## Implementation Notes

1. **Thread Safety**: The service is not thread-safe. Ensure all calls are made from the same isolate (typically the UI thread).

2. **State Persistence**: Impersonation state is not persisted across app restarts. If the app is closed while impersonating, the state is lost.

3. **Audit Log Dependency**: The service requires a valid `actorId` from the PocketBase gateway for audit logging. Ensure the user is authenticated before using impersonation.

4. **UI Integration**: The service is designed to work with Flutter's reactive UI patterns. Use `ListenableBuilder` or similar widgets to react to state changes.

## Related Components

- **TenantContext**: Manages the active tenant context
- **AuditLogService**: Logs impersonation events
- **Foundation Shell**: Displays the impersonation banner (Task 21.2)
- **Tenant List**: Provides the "Impersonate" action (Task 21.1)
