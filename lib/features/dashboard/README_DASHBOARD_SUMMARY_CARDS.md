# Dashboard Summary Cards (Q4)

## Overview

The Dashboard Summary Cards provide superadmins with a quick overview of platform health through four key metrics displayed at the top of the dashboard.

## Requirements Satisfied

- **Q4.1**: Display four summary cards: Total Tenants, Active, At Risk, Expiring Soon
- **Q4.2**: Compute card values from local `TenantUsageBillingView` stream without network calls
- **Q4.3**: Total Tenants = count of all `TenantLicenseEntries`
- **Q4.4**: Active = count where `isActive = true`
- **Q4.5**: At Risk = count where seat utilization ≥ 90% OR overdueInvoices > 0 OR outstandingAmount > 0
- **Q4.6**: Expiring Soon = count of active tenants with `licenseExpiresAt` ≤ 30 days from now
- **Q4.7**: Update all cards within one frame when Drift stream emits
- **Q4.8**: Dashboard aggregation invariant (testable via property tests)

## Metrics

### 1. Total Tenants (Q4.3)
- **Definition**: Count of all tenant license entries
- **Color**: Blue
- **Icon**: Business
- **Formula**: `tenants.length`

### 2. Active (Q4.4)
- **Definition**: Count of tenants with active licenses
- **Color**: Green
- **Icon**: Check Circle
- **Formula**: `tenants.where((t) => t.licenseActive == true).length`

### 3. At Risk (Q4.5)
- **Definition**: Count of tenants meeting any of these criteria:
  - Seat utilization ≥ 90%
  - Overdue invoices > 0
  - Outstanding amount > 0
- **Color**: Orange
- **Icon**: Warning
- **Formula**: 
  ```dart
  tenants.where((t) {
    if ((t.overdueInvoices ?? 0) > 0) return true;
    if ((t.outstandingAmount ?? 0) > 0) return true;
    if (seatLimit > 0 && activeStudents / seatLimit >= 0.9) return true;
    return false;
  }).length
  ```

### 4. Expiring Soon (Q4.6)
- **Definition**: Count of active tenants with license expiring within 30 days
- **Color**: Red
- **Icon**: Schedule
- **Formula**: 
  ```dart
  tenants.where((t) {
    if (t.licenseActive != true) return false;
    if (t.licenseExpiresAt == null) return false;
    return t.licenseExpiresAt <= now + 30 days;
  }).length
  ```

## Implementation

### Data Source

All metrics are computed from `TenantUsageBillingView` which provides:
- License status (`licenseActive`)
- Seat information (`seatLimit`, `activeStudents`)
- Billing data (`overdueInvoices`, `outstandingAmount`)
- Expiry dates (`licenseExpiresAt`)

### Reactive Updates (Q4.7)

The widget uses `StreamBuilder` with Drift's `watchTenantUsageBillingViews()`:
- Stream emits when any tenant data changes
- All four cards update simultaneously within one frame
- No manual refresh needed

### Responsive Layout

- **Desktop (>800px)**: 4 columns (all cards in one row)
- **Mobile (≤800px)**: 2 columns (cards in 2x2 grid)
- Aspect ratio adjusts for optimal display

## Usage

```dart
// In SuperadminDashboard
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Dashboard')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Q4.1: Summary cards at top
          DashboardSummaryCards(
            syncEngine: syncEngine,
          ),
          const SizedBox(height: 24),
          
          // Rest of dashboard content
          _buildTenantList(),
          _buildAlertBanners(),
        ],
      ),
    ),
  );
}
```

## Testing

### Property Test (Q4.8)

**Dashboard summary aggregation invariant:**

Test that card values are consistent with underlying data:
- `Active + Suspended == Total`
- `At Risk ≤ Total`
- `Expiring Soon ≤ Active`
- All values ≥ 0

Generate arbitrary tenant lists and verify invariants hold.

### Example Property Test

```dart
test('dashboard aggregation invariant', () {
  fc.assert(
    fc.property(
      fc.array(tenantArbitrary),
      (tenants) {
        final metrics = computeMetrics(tenants);
        
        // Active + Suspended should equal Total
        final suspended = tenants.where((t) => !t.licenseActive).length;
        expect(metrics.activeTenants + suspended, equals(metrics.totalTenants));
        
        // At Risk should not exceed Total
        expect(metrics.atRiskTenants, lessThanOrEqualTo(metrics.totalTenants));
        
        // Expiring Soon should not exceed Active
        expect(metrics.expiringSoonTenants, lessThanOrEqualTo(metrics.activeTenants));
        
        // All values should be non-negative
        expect(metrics.totalTenants, greaterThanOrEqualTo(0));
        expect(metrics.activeTenants, greaterThanOrEqualTo(0));
        expect(metrics.atRiskTenants, greaterThanOrEqualTo(0));
        expect(metrics.expiringSoonTenants, greaterThanOrEqualTo(0));
      },
    ),
  );
});
```

## At Risk Logic

The "At Risk" metric uses the same logic as `UsageBillingMonitorPage._isAtRisk`:

1. **Financial Risk**: Overdue invoices or outstanding balance
2. **Capacity Risk**: Seat utilization ≥ 90%

This provides early warning for:
- Tenants approaching seat limits (need upgrade)
- Tenants with payment issues (need follow-up)

## Performance Considerations

- **No Network Calls**: All data from local Drift database (Q4.2)
- **Single Query**: One stream provides all data for all cards
- **Efficient Computation**: Metrics computed in single pass over tenant list
- **Reactive**: Only recomputes when data actually changes

## Future Enhancements

1. Add click handlers to navigate to filtered views
   - Click "At Risk" → show only at-risk tenants
   - Click "Expiring Soon" → show tenants expiring soon
2. Add trend indicators (↑↓) showing change from previous period
3. Add sparkline charts showing metric history
4. Add export metrics to CSV
5. Add customizable metric thresholds
6. Add more metrics:
   - Total Revenue
   - Average Seat Utilization
   - Churn Rate
   - Growth Rate

## Integration Notes

The cards are designed to be placed at the top of the Superadmin Dashboard, providing immediate visibility into platform health before diving into detailed tenant lists and reports.

All metrics update automatically when:
- New tenants are created
- License status changes
- Usage metrics sync from PocketBase
- Billing information updates
