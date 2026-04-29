# Tenant Detail Page (Q1)

## Overview

The Tenant Detail Page provides a comprehensive view of all tenant information in one place, eliminating the need for superadmins to navigate between multiple pages to answer support queries.

## Requirements Satisfied

- **Q1.1**: Display comprehensive tenant information
- **Q1.2**: Load data from local Drift tables without network calls
- **Q1.3**: Provide "Impersonate" button
- **Q1.4**: Provide "Edit License" button
- **Q1.5**: Provide "Suspend/Activate" toggle
- **Q1.6**: Auto-refresh on sync completion via Drift streams

## Features

### Information Displayed

**Basic Information:**
- Tenant Name
- Tenant ID
- Plan (Starter/Professional/Enterprise)
- Seat Limit
- Activation Status (Active/Suspended)

**License Information:**
- License Expiry Date

**Owner Information:**
- Owner Email (note: not available in TenantUsageBillingView, requires separate query)

**Usage Statistics:**
- Active Students count
- Active Staff count
- Monthly Active Users (MAU)
- Storage consumed (GB)

**Billing Information:**
- Outstanding Amount
- Overdue Invoices count

### Actions

1. **Impersonate Tenant** (Q1.3)
   - Sets TenantContext to the selected tenant with `isSuperAdmin = true`
   - Uses ImpersonationService for proper audit logging
   - Navigates back to dashboard after impersonation starts

2. **Edit License** (Q1.4)
   - Navigates to TenantLicensingPage pre-populated with tenant data
   - Currently shows placeholder message (routing integration needed)

3. **Suspend/Activate Toggle** (Q1.5)
   - Toggles tenant activation status
   - Queries for license ID before updating
   - Updates via `setTenantLicenseStatus` database method
   - Shows success/error feedback

## Data Source

All data is loaded from `TenantUsageBillingView` which combines:
- Tenant records
- License entries
- Usage metrics
- Billing information

The view is watched via Drift streams, ensuring automatic updates when sync completes (Q1.6).

## Usage

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => TenantDetailPage(
      tenantId: 'tenant_123',
      syncEngine: syncEngine,
      impersonationService: impersonationService,
    ),
  ),
);
```

## Implementation Notes

1. **No Network Calls**: All data is loaded from local Drift database (Q1.2)
2. **Reactive Updates**: Uses StreamBuilder with Drift streams for automatic refresh (Q1.6)
3. **License ID Query**: Since TenantUsageBillingView doesn't include licenseId, we query TenantLicenseEntries separately when needed
4. **Owner Email**: Not available in the view - shows placeholder. Consider adding to view or querying separately if needed.

## Future Enhancements

1. Add navigation integration for "Edit License" button
2. Add owner email query from SchoolOwnerEntries
3. Add tenant activity timeline
4. Add quick actions for common support tasks
5. Add export tenant data to PDF/CSV
