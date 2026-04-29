# Plan Upgrade Request Flow

**Feature:** scholify-roadmap-tracker  
**Requirements:** B2.1, B2.2, B2.3, B2.4, B2.5, B2.6, B2.7, B2.8

## Overview

The Plan Upgrade Request Flow allows school owners to submit plan upgrade requests from within the app. The Superadmin is notified and can action the upgrade without requiring an out-of-band email.

## Components

### 1. PlanComparisonService (`core/services/plan_comparison_service.dart`)

Service for comparing plan tiers and determining valid upgrade options.

**Plan Hierarchy:**
1. Starter (lowest tier)
2. Professional
3. Enterprise (highest tier)

**Methods:**
- `isUpgrade(currentPlan, requestedPlan)`: Returns true if requested plan is higher than current
- `getUpgradeOptions(currentPlan)`: Returns list of valid upgrade options
- `getPlanDisplayName(planCode)`: Returns formatted display name for a plan

### 2. PlanUpgradePage (`presentation/plan_upgrade_page.dart`)

The UI page for school owners to submit upgrade requests.

**Features:**
- Accessible to School_Owner role users (B2.1)
- Displays current plan (read-only) (B2.2)
- Shows dropdown with only higher plans (B2.2, B2.3)
- Optional message textarea (B2.2)
- Validates requested plan > current plan (B2.3)
- Persists request locally and enqueues for sync (B2.4)
- Shows pending request status if one exists (B2.8)
- Displays approved/rejected status after review

**Validation:**
- Prevents submission if requested plan ≤ current plan (B2.3)
- Shows error if no upgrade options available (already on highest plan)

### 3. PlanUpgradeReviewPage (`presentation/plan_upgrade_review_page.dart`)

The UI page for superadmins to review and action upgrade requests.

**Features:**
- Lists all pending upgrade requests (B2.5)
- Shows tenant name, current plan, requested plan, message
- Displays submission date
- "Approve" button (B2.6):
  - Updates TenantLicenseEntry with new plan code
  - Marks request as 'approved'
  - Enqueues sync operations
- "Reject" button (B2.7):
  - Marks request as 'rejected'
  - Enqueues sync operation
- Confirmation dialogs for both actions
- Real-time updates via Drift streams

## User Flows

### School Owner Flow

1. Navigate to Settings → "Request Plan Upgrade"
2. View current plan
3. Select desired plan from dropdown (only higher plans shown)
4. Optionally add a message explaining the need
5. Submit request
6. See confirmation: "Upgrade request submitted. You will be notified when reviewed."
7. If pending request exists, see status instead of form
8. After review, see approved/rejected status on next visit

### Superadmin Flow

1. Navigate to Superadmin Dashboard
2. See "Upgrade Requests" badge with count of pending requests (B2.5)
3. Click to open PlanUpgradeReviewPage
4. Review each request with tenant details
5. Click "Approve" to:
   - Update tenant's license plan
   - Mark request as approved
   - Notify school owner (via sync)
6. Or click "Reject" to:
   - Mark request as rejected
   - Notify school owner (via sync)

## Database Schema

**PlanUpgradeRequestEntries:**
- `id`: Unique identifier
- `tenantId`: Reference to tenant
- `currentPlan`: Plan at time of request
- `requestedPlan`: Desired plan
- `message`: Optional message from school owner
- `status`: 'pending', 'approved', or 'rejected'
- `reviewedBy`: Superadmin who reviewed (if reviewed)
- `createdAt`: Submission timestamp
- `reviewedAt`: Review timestamp (if reviewed)
- `updatedAt`: Last update timestamp

## Integration

### Adding to School Owner Settings

```dart
// In your settings page or menu
ListTile(
  leading: const Icon(Icons.upgrade),
  title: const Text('Request Plan Upgrade'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanUpgradePage(
          tenantContext: tenantContext,
          syncEngine: syncEngine,
        ),
      ),
    );
  },
),
```

### Adding to Superadmin Dashboard

```dart
// In SuperadminDashboardPage
StreamBuilder<int>(
  stream: _watchPendingUpgradeRequestCount(),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    return Badge(
      label: Text('$count'),
      isLabelVisible: count > 0,
      child: IconButton(
        icon: const Icon(Icons.upgrade),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanUpgradeReviewPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
    );
  },
),

// Helper method
Stream<int> _watchPendingUpgradeRequestCount() {
  return (syncEngine.database
        .select(syncEngine.database.planUpgradeRequestEntries)
      ..where((tbl) => tbl.status.equals('pending')))
      .watch()
      .map((requests) => requests.length);
}
```

## Requirements Satisfied

- ✅ B2.1: Page accessible to School_Owner role users
- ✅ B2.2: Captures current plan, requested plan, optional message
- ✅ B2.3: Prevents submission if requested plan ≤ current plan
- ✅ B2.4: Persists PlanUpgradeRequestEntry locally and enqueues for sync
- ✅ B2.5: Superadmin Dashboard displays badge with pending request count
- ✅ B2.6: Approve button updates license and marks request as approved
- ✅ B2.7: Reject button marks request as rejected
- ✅ B2.8: Displays pending request status instead of form if one exists

## Testing

Property-based tests for plan comparison logic should verify:
- `isUpgrade('starter', 'professional')` returns true
- `isUpgrade('professional', 'starter')` returns false
- `isUpgrade('starter', 'starter')` returns false
- All plan pairs are correctly compared

Integration tests should verify:
- Complete request submission flow
- Approval updates license correctly
- Rejection updates status correctly
- Status transitions (pending → approved/rejected)
