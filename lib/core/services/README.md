# Core Services

This directory contains core business logic services for the Scholify platform.

## AuditLogService

The `AuditLogService` intercepts all write operations to auditable entities and creates append-only audit log entries with actor, action, entity, and timestamp information.

### Usage Example

```dart
import 'package:scholify/core/services/audit_log_service.dart';

// Initialize the service (typically done via dependency injection)
final auditLogService = AuditLogService(
  database: database,
  tenantContext: tenantContext,
  gateway: gateway,
);

// Log a write operation
await auditLogService.logWrite(
  entityType: 'TenantRecord',
  entityId: 'tenant_001',
  operation: 'update',
  changedFields: {
    'name': 'Updated School Name',
    'isActive': true,
    'updatedAt': DateTime.now().toIso8601String(),
  },
);
```

### Requirements

- **H3.1**: Record audit entry for every write operation
- **H3.2**: Capture actor user ID, actor role, entity type, entity ID, operation type, timestamp, and JSON snapshot of changed fields

### Implementation Details

1. **Actor Information**: Captured from `TenantContext` (role) and `PocketbaseGateway` (user ID)
2. **JSON Snapshot**: Changed fields are serialized to JSON using `jsonEncode`
3. **Drift Storage**: Audit entries are written to the `AuditLogEntries` table
4. **Sync Queue**: Entries are enqueued for push-only sync to PocketBase

### Auditable Entities

The following entities should be logged:
- `TenantRecord`
- `TenantLicenseEntry`
- `SchoolOwnerEntry`
- `TenantFeatureFlagEntry`
- `StudentEnrollmentEntry`

### Operation Types

- `create`: New entity created
- `update`: Existing entity modified
- `delete`: Entity deleted

### Error Handling

The service throws an `Exception` if:
- `tenantId` is empty (no active tenant context)
- `actorId` is empty (no authenticated user)

### Testing

Unit tests are located in `test/core/services/audit_log_service_test.dart`.

Property-based tests for audit log invariants are in task 2.2 of the implementation plan.

---

## LicenseAlertService

The `LicenseAlertService` computes days remaining until license expiry and classifies licenses into alert tiers (warning30, alert14, urgent7, expired) for display on the Superadmin Dashboard.

### Usage Example

```dart
import 'package:scholify/core/services/license_alert_service.dart';

// Initialize the service (typically done via dependency injection)
final alertService = LicenseAlertService(database: database);

// Watch for license alerts (reactive stream)
alertService.watchAlerts().listen((alerts) {
  for (final alert in alerts) {
    print('${alert.tenantName}: ${alert.daysRemaining} days remaining (${alert.tier})');
  }
});

// Or compute alerts at a specific point in time
final licenses = await database.getTenantLicenseViews();
final now = DateTime.now();
final alerts = alertService.computeAlerts(licenses, now);
```

### Requirements

- **H4.1**: Compute days remaining until expiry for all active licenses
- **H4.2**: Warning tier (30 or fewer days remaining)
- **H4.3**: Alert tier (14 or fewer days remaining)
- **H4.4**: Urgent tier (7 or fewer days remaining)
- **H4.5**: Expired tier (license has expired)
- **H4.6**: Licenses with null expiry dates generate no alerts
- **H4.7**: Recompute alerts on sync cycle completion

### Alert Tiers

The service classifies licenses into the following tiers based on days remaining:

| Tier | Days Remaining | Description |
|------|----------------|-------------|
| `none` | > 30 | No alert needed |
| `warning30` | 15-30 | Yellow badge on tenant card |
| `alert14` | 8-14 | Amber banner on dashboard |
| `urgent7` | 0-7 | Red banner on dashboard |
| `expired` | < 0 | License has expired |

### Implementation Details

1. **Reactive Stream**: `watchAlerts()` provides a stream that emits new alerts whenever license data changes
2. **Pure Function**: `computeAlerts()` is a pure function that takes licenses and a timestamp, returning alerts
3. **Filtering**: Only active licenses with non-null expiry dates are included
4. **Alert Tier Computation**: `computeAlertTier()` implements the tier thresholds as a pure function

### Alert Model

```dart
class LicenseAlert {
  final String tenantId;
  final String tenantName;
  final DateTime expiresAt;
  final int daysRemaining;
  final AlertTier tier;
}

enum AlertTier {
  none,
  warning30,
  alert14,
  urgent7,
  expired,
}
```

### Testing

Unit tests are located in `test/core/services/license_alert_service_test.dart`.

The tests cover:
- Alert tier computation for all thresholds
- Boundary conditions (exactly 7, 14, 30 days)
- Filtering of inactive licenses
- Filtering of licenses with null expiry dates
- Multiple licenses with different tiers
