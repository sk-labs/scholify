# Impersonate Tenant Feature (Q3)

## Overview

The Impersonate Tenant feature allows superadmins to view the application from a tenant's perspective without needing their credentials. This is essential for diagnosing issues and providing support.

## Requirements Satisfied

- **Q3.1**: Display "Impersonate" action for each tenant row (visible only to superadmin)
- **Q3.2**: Set TenantContext with selected tenant and `isSuperAdmin = true`
- **Q3.3**: Display persistent banner during impersonation
- **Q3.4**: End impersonation by tapping banner, restore superadmin context
- **Q3.5**: Render module destinations appropriate for impersonated tenant
- **Q3.6**: Record audit log entries for impersonation start/end

## Features

### Impersonation Actions

**Start Impersonation:**
1. Superadmin clicks "Impersonate" action on tenant list row
2. `ImpersonationService.startImpersonation(tenantId, tenantName)` is called
3. TenantContext is set with:
   - `tenantId`: Selected tenant's ID
   - `tenantName`: Selected tenant's name
   - `role`: 'school_owner'
   - `isSuperAdmin`: true (preserves superadmin privileges)
4. Audit log entry is created (Q3.6)
5. Impersonation banner appears

**End Impersonation:**
1. Superadmin taps the impersonation banner
2. `ImpersonationService.endImpersonation()` is called
3. TenantContext is restored to superadmin's original context
4. Audit log entry is created (Q3.6)
5. Banner disappears

### Impersonation Banner

The `ImpersonationBanner` widget:
- Shows persistent orange banner at top of screen (Q3.3)
- Displays: "Impersonating: [tenant name] — tap to exit"
- Only visible when `isImpersonating = true`
- Tappable to end impersonation (Q3.4)
- Uses StreamBuilder to react to impersonation state changes

### Module Rendering

While impersonating (Q3.5):
- Foundation Shell renders modules based on impersonated tenant's:
  - Plan (starter/professional/enterprise)
  - Feature flags
  - Permissions
- Superadmin retains `isSuperAdmin = true` for elevated access
- Can access both tenant-specific and superadmin features

## Implementation

### ImpersonationService

The service manages impersonation state and audit logging:

```dart
class ImpersonationService {
  final TenantContext tenantContext;
  final AuditLogService auditLogService;

  // Start impersonation
  Future<void> startImpersonation(String tenantId, String tenantName);

  // End impersonation
  Future<void> endImpersonation();

  // Watch impersonation state
  Stream<ImpersonationState> watchImpersonationState();
}
```

### Integration with Foundation Shell

Add the banner to your shell's build method:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Q3.3: Impersonation banner
        ImpersonationBanner(
          impersonationService: impersonationService,
        ),
        // Rest of your shell UI
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    ),
  );
}
```

### Adding Impersonate Action to Tenant List

```dart
// In tenant list row actions
if (tenantContext.isSuperAdmin)
  TextButton.icon(
    onPressed: () => _handleImpersonate(tenant),
    icon: const Icon(Icons.person_outline),
    label: const Text('Impersonate'),
  ),

Future<void> _handleImpersonate(Tenant tenant) async {
  await impersonationService.startImpersonation(
    tenant.tenantId,
    tenant.tenantName,
  );
  // Navigate to tenant dashboard or refresh UI
}
```

## Audit Logging

All impersonation actions are logged (Q3.6):

**Start Impersonation:**
- `entityType`: 'impersonation'
- `operation`: 'start'
- `actorId`: Superadmin user ID
- `changedFields`: `{"targetTenantId": "...", "targetTenantName": "..."}`

**End Impersonation:**
- `entityType`: 'impersonation'
- `operation`: 'end'
- `actorId`: Superadmin user ID
- `changedFields`: `{"previousTenantId": "...", "previousTenantName": "..."}`

## Security Considerations

1. **Superadmin Only**: Impersonate action only visible when `isSuperAdmin = true`
2. **Audit Trail**: All impersonation sessions are logged for compliance
3. **Preserved Privileges**: `isSuperAdmin` flag remains true during impersonation
4. **Clear Indication**: Banner ensures superadmin always knows they're impersonating
5. **Easy Exit**: Single tap to end impersonation session

## Testing

### Property Test (Q3.3)

**Banner visibility invariant:**
- Banner shown ⟺ impersonation active
- Test over arbitrary context states

### Unit Tests (Q3.2, Q3.4)

**TenantContext state transitions:**
- Test impersonation start sets correct context
- Test impersonation end restores original context
- Test audit log entries are created

## Usage Example

```dart
// In TenantLicensingPage or similar
TextButton.icon(
  onPressed: () async {
    await impersonationService.startImpersonation(
      tenant.tenantId,
      tenant.tenantName,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now impersonating ${tenant.tenantName}'),
      ),
    );
  },
  icon: const Icon(Icons.person_outline),
  label: const Text('Impersonate'),
),
```

## Future Enhancements

1. Add impersonation time limit (auto-end after X minutes)
2. Add impersonation history view
3. Add "Impersonate as different role" option
4. Add impersonation session recording for compliance
5. Add multi-level impersonation (impersonate staff within tenant)
