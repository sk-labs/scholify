# Design Document — Scholify Roadmap Tracker

## Overview

This design document provides the technical architecture, data models, UI flows, and implementation guidance for 11 planned requirements across the Scholify multi-tenant school management platform. The requirements span four priority tiers:

- **HIGH IMPACT**: Tenant Onboarding Wizard, Tenant Search/Filtering, Audit Log, License Expiry Alerts
- **ARCHITECTURE / RELIABILITY**: PocketBase Rules Verification, Sync Failure Visibility, Seat Limit Enforcement
- **BUSINESS / GROWTH**: Self-Service Signup, Plan Upgrade Request Flow, Per-Tenant Branding, Usage Analytics
- **QUICK WINS**: Tenant Detail Page, Export Tenant List to CSV, Impersonate Tenant, Superadmin Dashboard Summary Cards

The design builds on the existing Scholify architecture: Flutter desktop-first app with web support, Drift offline-first local persistence, PocketBase remote backend, and a sync engine that processes an outbox queue for push operations and checkpoint-based pull sync.

### Key Design Principles

1. **Offline-First**: All writes go to Drift immediately; sync happens asynchronously
2. **Tenant Isolation**: Every entity is scoped to `tenant_id`; PocketBase rules enforce server-side isolation
3. **Superadmin Control Plane**: Superadmin role has cross-tenant visibility and management capabilities
4. **Plan-Based Access**: Module access is determined by plan defaults + per-tenant feature flag overrides
5. **Audit Trail**: All significant writes are logged with actor, action, entity, and timestamp
6. **Graceful Degradation**: UI remains functional when sync fails; failed operations are visible and retryable

---

## Architecture

### System Context

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Desktop/Web App                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Superadmin   │  │ School Owner │  │ Staff/Student│      │
│  │ Dashboard    │  │ Dashboard    │  │ Modules      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                 │
│                   ┌────────▼────────┐                        │
│                   │  TenantContext  │                        │
│                   │  (active tenant,│                        │
│                   │   role, flags)  │                        │
│                   └────────┬────────┘                        │
│                            │                                 │
│         ┌──────────────────┴──────────────────┐             │
│         │                                      │             │
│  ┌──────▼──────┐                      ┌───────▼──────┐      │
│  │   Drift     │◄─────────────────────┤ SyncEngine   │      │
│  │  (SQLite)   │                      │ (background) │      │
│  └─────────────┘                      └───────┬──────┘      │
│                                               │              │
└───────────────────────────────────────────────┼──────────────┘
                                                │
                                                │ HTTPS
                                                │
                                        ┌───────▼──────┐
                                        │  PocketBase  │
                                        │   Backend    │
                                        └──────────────┘
```

### Component Responsibilities

**TenantContext**: Holds active `tenant_id`, `tenant_name`, `role`, and `isSuperAdmin` flag. Notifies listeners on context changes (e.g., impersonation).

**Drift Database**: Local SQLite persistence layer. All tables include `tenant_id` for scoping. Provides reactive streams for UI updates.

**SyncEngine**: Background service that:
- Processes `SyncQueueEntries` (outbox) in batches
- Executes checkpoint-based pull sync per entity type
- Enforces tenant scope for non-superadmin contexts
- Tracks pending job count and last sync timestamp

**PocketBase Gateway**: HTTP client wrapper for PocketBase REST API. Handles auth token refresh and tenant-scoped query filters.

**ModuleAccessPolicy**: Resolves effective feature map from plan defaults + feature flag overrides. Superadmin always gets all features.

---

## Components and Interfaces

### New Drift Tables

#### AuditLogEntries

```dart
class AuditLogEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get actorId => text()();
  TextColumn get actorRole => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get changedFields => text()(); // JSON snapshot
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

**Indexes**: `(tenantId, timestamp DESC)`, `(entityType, timestamp DESC)`, `(actorId, timestamp DESC)`

**Sync**: Push-only. No pull sync required (audit log is append-only and generated locally).

#### PlanUpgradeRequestEntries

```dart
class PlanUpgradeRequestEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get currentPlan => text()();
  TextColumn get requestedPlan => text()();
  TextColumn get message => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'approved', 'rejected'
  TextColumn get reviewedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

**Indexes**: `(tenantId, status)`, `(status, createdAt DESC)`

**Sync**: Push on creation, pull for status updates.

#### TenantBrandingEntries

```dart
class TenantBrandingEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get displayName => text()();
  TextColumn get logoBase64 => text().nullable()(); // base64-encoded PNG/JPEG
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

**Indexes**: `(tenantId)`

**Sync**: Push on update, pull for cross-device consistency.

### Extended Drift Views

#### TenantDetailView

Combines `TenantRecords`, `TenantLicenseEntries`, `SchoolOwnerEntries`, and `TenantUsageMetricEntries` for the Tenant Detail Page.

```dart
@DriftAccessor(tables: [
  TenantRecords,
  TenantLicenseEntries,
  SchoolOwnerEntries,
  TenantUsageMetricEntries,
])
class TenantDetailView {
  String tenantId;
  String tenantName;
  bool isActive;
  String planCode;
  int seatLimit;
  DateTime? expiresAt;
  String ownerEmail;
  int activeStudents;
  int activeStaff;
  int monthlyActiveUsers;
  double storageGb;
  double outstandingAmount;
  int overdueInvoices;
}
```

### New Services

#### AuditLogService

**Responsibilities**:
- Intercept all write operations to auditable entities
- Capture actor context from `TenantContext`
- Generate JSON snapshot of changed fields
- Write `AuditLogEntry` to Drift
- Enqueue audit entry for push sync

**Interface**:
```dart
class AuditLogService {
  Future<void> logWrite({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> changedFields,
  });
}
```

#### LicenseAlertService

**Responsibilities**:
- Compute days remaining until expiry for all active licenses
- Classify licenses into alert tiers (30d, 14d, 7d, expired)
- Provide reactive stream of alert states for dashboard

**Interface**:
```dart
class LicenseAlertService {
  Stream<List<LicenseAlert>> watchAlerts();
  List<LicenseAlert> computeAlerts(List<TenantLicenseView> licenses, DateTime now);
}

class LicenseAlert {
  final String tenantId;
  final String tenantName;
  final DateTime expiresAt;
  final int daysRemaining;
  final AlertTier tier; // warning30, alert14, urgent7, expired
}
```

#### SeatLimitEnforcementService

**Responsibilities**:
- Check active enrollment count against license seat limit before allowing new enrollment
- Throw `SeatLimitExceededException` when limit is reached

**Interface**:
```dart
class SeatLimitEnforcementService {
  Future<void> checkSeatLimit(String tenantId);
}

class SeatLimitExceededException implements Exception {
  final int currentCount;
  final int seatLimit;
}
```

#### CSVExportService

**Responsibilities**:
- Serialize tenant list to RFC 4180 compliant CSV
- Escape commas, quotes, and newlines per spec
- Trigger platform-specific file save dialog

**Interface**:
```dart
class CSVExportService {
  Future<void> exportTenantList(List<TenantLicenseView> tenants);
}
```

#### ImpersonationService

**Responsibilities**:
- Set `TenantContext` to impersonated tenant with `isSuperAdmin = true`
- Log impersonation start/end to audit log
- Provide banner state for UI

**Interface**:
```dart
class ImpersonationService {
  Future<void> startImpersonation(String tenantId, String tenantName);
  Future<void> endImpersonation();
  bool get isImpersonating;
  String? get impersonatedTenantName;
}
```

---

## Data Models

### Onboarding Wizard State

```dart
class OnboardingWizardState {
  final String schoolName;
  final String planCode;
  final int seatLimit;
  final String ownerEmail;
  final int currentStep; // 0: identity, 1: license, 2: owner
  final bool isSaving;
  final String? errorMessage;
}
```

### Tenant Filter Criteria

```dart
class TenantFilterCriteria {
  final String searchQuery;
  final String? planFilter; // null = all, 'starter', 'professional', 'enterprise'
  final bool? activeFilter; // null = all, true = active, false = suspended
}
```

### Dashboard Summary Metrics

```dart
class DashboardSummaryMetrics {
  final int totalTenants;
  final int activeTenants;
  final int atRiskTenants;
  final int expiringSoonTenants; // ≤30 days
}
```

---

## UI Flows

### H1: Tenant Onboarding Wizard

**Entry Point**: Superadmin Dashboard → "Create Tenant" button

**Steps**:
1. **Tenant Identity**: School name input → validate non-empty → derive `tenant_id` → check uniqueness
2. **License Configuration**: Plan dropdown (starter/professional/enterprise) + seat limit input → validate positive integer
3. **Owner Email**: Email input → validate format (contains @ and domain)
4. **Confirmation**: Display summary → "Create Tenant" button

**On Submit**:
- Begin Drift transaction
- Insert `TenantRecord` (id, name, isActive=true, createdAt)
- Insert `TenantLicenseEntry` (id, tenantId, planCode, seatLimit, isActive=true, issuedAt, expiresAt=now+365d)
- Insert `SchoolOwnerEntry` (id, tenantId, fullName=derived, email, isPrimary=true, provisioningStatus='pending')
- Enqueue 3 sync operations (tenant, license, owner)
- Commit transaction
- On success: show confirmation, navigate back to dashboard
- On failure: rollback, show error message

**Validation Rules**:
- School name: non-empty, max 100 chars
- Tenant ID: derived from school name (lowercase, replace non-alphanumeric with `_`), must not exist
- Plan: one of `starter`, `professional`, `enterprise`
- Seat limit: positive integer, min 10, max 10000
- Owner email: contains `@` and domain segment, max 100 chars

### H2: Tenant Search and Filtering

**Entry Point**: Superadmin Dashboard → "Tenant Licensing" page

**UI Components**:
- Search field (debounced 300ms)
- Filter chips: Plan (All / Starter / Professional / Enterprise), Status (All / Active / Suspended)
- Tenant list (cards or table rows)

**Filter Logic**:
```dart
List<TenantLicenseView> applyFilters(
  List<TenantLicenseView> all,
  TenantFilterCriteria criteria,
) {
  var filtered = all;
  
  if (criteria.searchQuery.isNotEmpty) {
    filtered = filtered.where((t) =>
      t.tenantName.toLowerCase().contains(criteria.searchQuery.toLowerCase())
    ).toList();
  }
  
  if (criteria.planFilter != null) {
    filtered = filtered.where((t) => t.planCode == criteria.planFilter).toList();
  }
  
  if (criteria.activeFilter != null) {
    filtered = filtered.where((t) => t.isActive == criteria.activeFilter).toList();
  }
  
  return filtered;
}
```

**Empty State**: "No tenants match the current filters."

### H3: Audit Log

**Entry Point**: Superadmin Dashboard → "Audit Log" menu item

**UI Components**:
- Filter dropdowns: Entity Type (All / Tenant / License / Owner / Enrollment / ...), Actor (All / specific user ID)
- Paginated list (50 entries per page)
- Each entry shows: timestamp, actor, entity type, entity ID, operation, changed fields (expandable JSON)

**Data Source**: `SELECT * FROM audit_log_entries WHERE tenant_id = ? ORDER BY timestamp DESC LIMIT 50 OFFSET ?`

**Filters**: Apply WHERE clauses for entity type and actor ID when selected.

### H4: License Expiry Alerts

**Entry Point**: Superadmin Dashboard (automatic on load)

**Alert Tiers**:
- **Warning (30d)**: Yellow badge on tenant card
- **Alert (14d)**: Amber banner at top of dashboard listing affected tenants
- **Urgent (7d)**: Red banner at top of dashboard listing affected tenants
- **Expired**: Tenant card shows "Expired" status in red

**Computation**:
```dart
AlertTier computeAlertTier(DateTime expiresAt, DateTime now) {
  final daysRemaining = expiresAt.difference(now).inDays;
  if (daysRemaining < 0) return AlertTier.expired;
  if (daysRemaining <= 7) return AlertTier.urgent7;
  if (daysRemaining <= 14) return AlertTier.alert14;
  if (daysRemaining <= 30) return AlertTier.warning30;
  return AlertTier.none;
}
```

**Refresh Trigger**: On app launch, after every sync cycle, on manual sync.

### A1: PocketBase Rules Verification

**Entry Point**: Standalone Dart script `bin/verify_pocketbase_rules.dart`

**Execution**: `dart run bin/verify_pocketbase_rules.dart`

**Logic**:
1. Load expected rules from `docs/POCKETBASE_TENANT_RULES.md` (hardcoded map)
2. Query PocketBase Admin API `/api/collections` for each collection
3. Compare `listRule`, `viewRule`, `createRule`, `updateRule`, `deleteRule` against expected
4. Print mismatches with collection name, rule type, expected, actual
5. Exit 0 if all match, exit 1 if any mismatch or connection error

**Output**:
```
Verifying PocketBase rules...
✓ tenants: all rules match
✗ student_profiles: listRule mismatch
  Expected: @request.auth.id != '' && (@request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id)
  Actual: @request.auth.id != ''
✓ tenant_licenses: all rules match
...
Summary: 2 collections with mismatches
```

### A2: Sync Failure Visibility

**Entry Point**: Foundation Shell → persistent warning icon in app bar (when failures > 0) → "Sync Failures" page

**UI Components**:
- List of failed sync entries (entity type, entity ID, operation, retry count, last error, last attempted timestamp)
- "Retry All" button (re-enqueues all failed entries)
- Per-entry "Dismiss" button (deletes entry from queue)

**Data Source**: `SELECT * FROM sync_queue_entries WHERE retry_count > 0 AND synced_at IS NULL ORDER BY updated_at DESC`

**Retry All Logic**:
```dart
Future<void> retryAllFailed() async {
  final failed = await database.getFailedSyncEntries();
  for (final entry in failed) {
    await database.resetSyncEntry(entry.id); // set retry_count=0, error_message=null
  }
  await syncEngine.manualSync();
}
```

**Dismiss Logic**:
```dart
Future<void> dismissFailedEntry(String entryId) async {
  await database.deleteSyncEntry(entryId);
}
```

### A3: Seat Limit Enforcement

**Entry Point**: Student Enrollment Page → "Enroll Student" action

**Enforcement Point**: Before inserting `StudentEnrollmentEntry`

**Logic**:
```dart
Future<void> enrollStudent(String studentId, String tenantId) async {
  final license = await database.getTenantLicense(tenantId);
  if (license == null) throw Exception('No license found for tenant');
  
  final activeCount = await database.countActiveEnrollments(tenantId);
  if (activeCount >= license.seatLimit) {
    throw SeatLimitExceededException(activeCount, license.seatLimit);
  }
  
  await database.insertEnrollment(studentId, tenantId);
}
```

**Error Handling**: Catch `SeatLimitExceededException` in UI, show snackbar: "Seat limit reached. Contact your administrator to upgrade the plan."

### B1: Self-Service Tenant Signup

**Entry Point**: Unauthenticated landing page → "Sign Up" button

**UI Components**:
- School name input
- Owner full name input
- Owner email input
- Password input (min 8 chars)
- "Create Account" button

**On Submit**:
1. Validate inputs (email format, password length)
2. Check email uniqueness via PocketBase API
3. Create PocketBase user account
4. Derive `tenant_id` from school name
5. Insert `TenantRecord`, `TenantLicenseEntry` (plan=starter, seatLimit=100, expiresAt=now+365d), `SchoolOwnerEntry`
6. Enqueue sync operations
7. Auto-sign-in user
8. Navigate to Foundation Shell

**Rollback**: If any step fails, delete created PocketBase user and local records.

### B2: Plan Upgrade Request Flow

**Entry Point**: School Owner → Foundation Shell → Settings → "Request Plan Upgrade"

**UI Components**:
- Current plan display (read-only)
- Requested plan dropdown (only plans higher than current)
- Optional message textarea
- "Submit Request" button

**On Submit**:
1. Validate requested plan > current plan
2. Insert `PlanUpgradeRequestEntry` (tenantId, currentPlan, requestedPlan, message, status='pending')
3. Enqueue sync operation
4. Show confirmation: "Upgrade request submitted. You will be notified when reviewed."

**Superadmin Review**:
- Superadmin Dashboard → "Upgrade Requests" badge (count of pending)
- List of pending requests with tenant name, current plan, requested plan, message
- "Approve" button: update `TenantLicenseEntry.planCode`, set request status='approved', enqueue sync
- "Reject" button: set request status='rejected', enqueue sync

**School Owner Notification**: On next sync, pull updated request status, show in-app notification.

### B3: Per-Tenant Branding

**Entry Point**: School Owner → Foundation Shell → Settings → "Branding"

**UI Components**:
- Display name input (pre-filled with tenant name)
- Logo upload button (PNG/JPEG, max 2MB)
- Logo preview
- "Save" button
- "Remove Logo" button

**On Save**:
1. Validate image size ≤ 2MB
2. Encode image to base64
3. Upsert `TenantBrandingEntry` (tenantId, displayName, logoBase64)
4. Enqueue sync operation
5. Notify `TenantContext` listeners to refresh shell

**Shell Rendering**:
```dart
Widget buildAppBar(BuildContext context) {
  final branding = await database.getTenantBranding(tenantContext.tenantId);
  final logo = branding?.logoBase64 != null
    ? Image.memory(base64Decode(branding!.logoBase64!))
    : Image.asset('assets/images/scholify_logo.png');
  final title = branding?.displayName ?? 'Scholify';
  
  return AppBar(
    leading: logo,
    title: Text(title),
  );
}
```

### B4: Usage Analytics for Superadmin

**Entry Point**: Superadmin Dashboard → "Usage Analytics" menu item

**UI Components**:
- Table: Tenant Name, Plan, Active Students, Active Staff, MAU, Storage GB, Module Engagement
- "Export CSV" button
- Click tenant row → detail view with 6-month MAU time-series chart

**Data Source**: `TenantUsageMetricEntries` (synced from PocketBase)

**Staleness Indicator**: If `updatedAt` > 24h ago, show "⚠ Data may be stale" next to tenant row.

**Module Engagement**: Query `AuditLogEntries` for each tenant, count distinct entity types with writes in last 30 days.

**CSV Export**: Same as Q2, add columns for MAU and module engagement.

### Q1: Tenant Detail Page

**Entry Point**: Superadmin Dashboard → Tenant List → Click tenant card

**UI Layout**:
- Header: Tenant name, tenant ID, activation status badge
- Section 1: License (plan, seat limit, expiry date, issued date)
- Section 2: Owner (email, phone, provisioning status)
- Section 3: Usage (active students, active staff, MAU, storage GB)
- Section 4: Billing (outstanding amount, overdue invoices, next billing date)
- Actions: "Impersonate", "Edit License", "Suspend/Activate"

**Data Source**: `TenantDetailView` (join of 4 tables)

**Impersonate Action**: Call `ImpersonationService.startImpersonation(tenantId, tenantName)`, navigate to Foundation Shell.

### Q2: Export Tenant List to CSV

**Entry Point**: Superadmin Dashboard → Tenant List → "Export CSV" button

**CSV Columns**: tenant_name, tenant_id, plan, seat_limit, is_active, license_expires_at, owner_email, active_students, outstanding_amount

**RFC 4180 Compliance**:
- Escape fields containing comma, quote, or newline
- Wrap escaped fields in double quotes
- Double-quote any quote character inside a field

**File Save**: Use `file_picker` package to trigger save dialog on desktop, share sheet on mobile.

### Q3: Impersonate Tenant

**Entry Point**: Superadmin Dashboard → Tenant List → "Impersonate" button on tenant card

**On Impersonate**:
1. Call `TenantContext.setTenant(tenantId, tenantName, role='school_owner', isSuperAdmin=true)`
2. Log audit entry: actor=superadmin, operation='impersonate_start', entityType='tenant', entityId=tenantId
3. Navigate to Foundation Shell
4. Show persistent banner: "Impersonating: [tenant name] — tap to exit"

**On Exit**:
1. Call `TenantContext.clearTenant(isSuperAdmin=true)`
2. Log audit entry: operation='impersonate_end'
3. Navigate back to Superadmin Dashboard

**Banner Widget**:
```dart
Widget buildImpersonationBanner(BuildContext context) {
  if (!impersonationService.isImpersonating) return SizedBox.shrink();
  
  return MaterialBanner(
    content: Text('Impersonating: ${impersonationService.impersonatedTenantName}'),
    actions: [
      TextButton(
        onPressed: () => impersonationService.endImpersonation(),
        child: Text('Exit'),
      ),
    ],
  );
}
```

### Q4: Superadmin Dashboard Summary Cards

**Entry Point**: Superadmin Dashboard (automatic on load)

**Cards**:
1. **Total Tenants**: Count of all `TenantLicenseEntries`
2. **Active**: Count where `isActive = true`
3. **At Risk**: Count where seat utilization ≥ 90% OR `overdueInvoices > 0` OR `outstandingAmount > 0`
4. **Expiring Soon**: Count where `expiresAt` ≤ now + 30 days AND `isActive = true`

**Computation**:
```dart
DashboardSummaryMetrics computeSummary(List<TenantUsageBillingView> tenants, DateTime now) {
  final total = tenants.length;
  final active = tenants.where((t) => t.isActive).length;
  final atRisk = tenants.where((t) =>
    (t.activeStudents / t.seatLimit >= 0.9) ||
    t.overdueInvoices > 0 ||
    t.outstandingAmount > 0
  ).length;
  final expiringSoon = tenants.where((t) =>
    t.isActive &&
    t.expiresAt != null &&
    t.expiresAt!.difference(now).inDays <= 30
  ).length;
  
  return DashboardSummaryMetrics(total, active, atRisk, expiringSoon);
}
```

**UI**: 4 cards in a row, each showing metric value and label.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Acceptance Criteria Testing Prework

Before writing correctness properties, I'll analyze each acceptance criterion to determine if it's testable as a property, example, edge case, integration test, or smoke test.


### Property Reflection

After analyzing all acceptance criteria, I've identified the following properties suitable for property-based testing. I'll now eliminate redundancy:

**Redundancy Analysis:**

1. **H4.2, H4.3, H4.4, H4.5** (alert tier thresholds) can be combined into a single comprehensive property that tests the alert tier computation function across all possible date pairs
2. **H2.5, H2.6** (plan filter, status filter) can be combined with **H2.7** (combined filters) into a single metamorphic property about filter composition
3. **H3.5, H3.6** (audit log filtering by entity type and actor) are similar filtering operations that can be tested with a single property about filter correctness
4. **A3.2** (seat limit enforcement) and **A3.6** (count decrease on delete) are related invariants about enrollment count consistency - keep both as they test different aspects
5. **B3.7** (logo size validation) and **B3.8** (logo encoding round-trip) test different properties - keep both
6. **B4.5** (staleness check) and **B4.7** (CSV round-trip) test different properties - keep both
7. **Q2.6** (CSV RFC 4180 escaping) is already covered by **B4.7** (CSV round-trip) - the round-trip property subsumes escaping correctness
8. **Q4.8** (Active + Suspended == Total) is a useful metamorphic property - keep it

**Properties to Write:**

After reflection, I'll write properties for:
- H1: Wizard validation (school name, plan, seat limit, email, atomicity)
- H2: Tenant filtering (metamorphic properties about filter composition)
- H3: Audit log (append-only invariant, field completeness, filtering)
- H4: License expiry alerts (alert tier computation)
- A2: Sync failure visibility (warning icon invariant)
- A3: Seat limit enforcement (boundary condition, count consistency)
- B1: Signup validation (email format, password length)
- B2: Plan upgrade (plan comparison)
- B3: Branding (logo size, encoding round-trip)
- B4: Usage analytics (staleness check, CSV round-trip)
- Q3: Impersonation (banner invariant)
- Q4: Dashboard summary (aggregation invariant)

### Property 1: Wizard School Name Validation

*For any* string input as school name, the wizard SHALL accept it if and only if it is non-empty after trimming whitespace.

**Validates: Requirements H1.2**

### Property 2: Wizard Plan and Seat Limit Validation

*For any* plan code and seat limit pair, the wizard SHALL accept it if and only if the plan is one of `starter`, `professional`, or `enterprise` (case-insensitive) AND the seat limit is a positive integer.

**Validates: Requirements H1.3**

### Property 3: Wizard Email Validation

*For any* string input as email, the wizard SHALL accept it if and only if it contains at least one `@` character followed by at least one character (domain segment).

**Validates: Requirements H1.4**

### Property 4: Wizard Atomic Write

*For any* valid wizard input (school name, plan, seat limit, email), when the wizard completes successfully, the database SHALL contain exactly one `TenantRecord`, one `TenantLicenseEntry`, one `SchoolOwnerEntry`, and three `SyncQueueEntries` for the created tenant.

**Validates: Requirements H1.5**

### Property 5: Tenant Filter Composition (Metamorphic)

*For any* tenant list and filter criteria (search query, plan filter, status filter), the following metamorphic properties SHALL hold:
- `filter(all, A AND B) ⊆ filter(all, A)`
- `filter(all, A AND B) ⊆ filter(all, B)`
- `filter(all, no_filters) == all`
- `|filter(all, A AND B)| <= min(|filter(all, A)|, |filter(all, B)|)`

**Validates: Requirements H2.1, H2.5, H2.6, H2.7**

### Property 6: Audit Log Append-Only Invariant

*For any* sequence of write operations, the count of audit log entries SHALL be monotonically increasing (never decrease).

**Validates: Requirements H3.3**

### Property 7: Audit Log Entry Completeness

*For any* write operation that generates an audit log entry, the entry SHALL contain non-null values for: `actorId`, `actorRole`, `entityType`, `entityId`, `operation`, `timestamp`, and `changedFields`.

**Validates: Requirements H3.2**

### Property 8: Audit Log Filter Correctness

*For any* audit log and filter criteria (entity type or actor ID), all entries in the filtered result SHALL match the filter criteria, and no matching entries from the original log SHALL be excluded.

**Validates: Requirements H3.5, H3.6**

### Property 9: License Expiry Alert Tier Computation

*For any* license expiry date and current date, the alert tier SHALL be computed as:
- `expired` if `expiresAt < now`
- `urgent7` if `0 <= daysRemaining <= 7`
- `alert14` if `8 <= daysRemaining <= 14`
- `warning30` if `15 <= daysRemaining <= 30`
- `none` if `daysRemaining > 30` or `expiresAt` is null

**Validates: Requirements H4.1, H4.2, H4.3, H4.4, H4.5, H4.6**

### Property 10: Sync Failure Warning Icon Invariant

*For any* application state, the Foundation Shell SHALL display a warning icon if and only if the count of failed sync entries (where `retryCount > 0` AND `syncedAt IS NULL`) is greater than zero.

**Validates: Requirements A2.7**

### Property 11: Seat Limit Enforcement Boundary

*For any* tenant with seat limit `L` and current active enrollment count `C`, a new enrollment SHALL be rejected if and only if `C >= L`.

**Validates: Requirements A3.2**

### Property 12: Enrollment Count Consistency

*For any* tenant, when a student enrollment is deleted or set to inactive, the active enrollment count SHALL decrease by exactly 1.

**Validates: Requirements A3.6**

### Property 13: Signup Password Length Validation

*For any* string input as password, the signup form SHALL accept it if and only if its length is at least 8 characters.

**Validates: Requirements B1.8**

### Property 14: Plan Upgrade Comparison

*For any* pair of plans (current, requested), the upgrade request SHALL be accepted if and only if `requested > current` in the ordering: `starter < professional < enterprise`.

**Validates: Requirements B2.3**

### Property 15: Logo File Size Validation

*For any* byte array representing an image file, the branding service SHALL accept it if and only if its size is less than or equal to 2,097,152 bytes (2 MB).

**Validates: Requirements B3.7**

### Property 16: Logo Encoding Round-Trip

*For any* valid image byte array, encoding to base64 and then decoding SHALL produce a byte array equal to the original.

**Validates: Requirements B3.8**

### Property 17: Usage Data Staleness Check

*For any* tenant usage metric with `lastSyncedAt` timestamp and current time `now`, the staleness indicator SHALL be shown if and only if `now - lastSyncedAt > 24 hours`.

**Validates: Requirements B4.5**

### Property 18: CSV Serialization Round-Trip

*For any* list of tenant records, serializing to CSV and then parsing SHALL produce a list of records equivalent to the original (field values preserved, order may vary).

**Validates: Requirements B4.7, Q2.6**

### Property 19: Impersonation Banner Invariant

*For any* application state, the Foundation Shell SHALL display an impersonation banner if and only if `ImpersonationService.isImpersonating == true`.

**Validates: Requirements Q3.3**

### Property 20: Dashboard Summary Aggregation Invariant

*For any* list of tenants, the dashboard summary metrics SHALL satisfy: `activeTenants + suspendedTenants == totalTenants` where `suspendedTenants = totalTenants - activeTenants`.

**Validates: Requirements Q4.8**

---

## Error Handling

### Validation Errors

**User Input Validation**: All form inputs SHALL be validated client-side before submission. Validation errors SHALL be displayed inline next to the relevant field with clear, actionable messages.

**Common Validation Patterns**:
- Non-empty strings: "This field is required."
- Email format: "Enter a valid email address."
- Positive integers: "Enter a number greater than zero."
- File size limits: "File must be under 2 MB."

### Database Errors

**Transaction Rollback**: All multi-step write operations (e.g., onboarding wizard, self-service signup) SHALL use Drift transactions. If any step fails, the transaction SHALL be rolled back and the user SHALL see an error message identifying the failed operation.

**Unique Constraint Violations**: When a unique constraint is violated (e.g., duplicate tenant ID, duplicate email), the error message SHALL clearly state which field caused the conflict.

### Sync Errors

**Network Failures**: When sync operations fail due to network issues, the operation SHALL remain in the sync queue with an incremented retry count. The user SHALL see the failure in the Sync Failure Page with the error message from PocketBase.

**Retry Strategy**: Failed sync operations SHALL be retried with exponential backoff (1s, 2s, 4s, 8s, 16s, max 30s). After 5 failed attempts, the operation SHALL remain in the queue but SHALL NOT be automatically retried until the user manually triggers "Retry All" or dismisses it.

**Conflict Resolution**: When a sync operation conflicts with a newer server-side update (based on `updated_at` timestamp), the server version SHALL win. The local change SHALL be discarded and the user SHALL be notified via a snackbar: "Your changes were overwritten by a newer update from another device."

### Authorization Errors

**Insufficient Permissions**: When a user attempts an action they don't have permission for (e.g., non-superadmin trying to create a tenant), the UI SHALL prevent the action by hiding or disabling the relevant controls. If the user somehow triggers the action (e.g., via API manipulation), the server SHALL return a 403 Forbidden error and the client SHALL display: "You don't have permission to perform this action."

**Expired Session**: When a user's PocketBase auth token expires, the sync engine SHALL attempt to refresh the token. If refresh fails, the user SHALL be signed out and redirected to the login page with a message: "Your session has expired. Please sign in again."

### Business Logic Errors

**Seat Limit Exceeded**: When enrollment is rejected due to seat limit, the error message SHALL state: "Seat limit reached. Contact your administrator to upgrade the plan." The message SHALL include the current count and limit: "Currently enrolled: 250 / 250 seats."

**Invalid Plan Upgrade**: When a plan upgrade request is invalid (e.g., downgrade or same plan), the error message SHALL state: "You can only upgrade to a higher plan. Current: Professional, Requested: Starter."

**Duplicate Tenant**: When onboarding wizard detects a duplicate tenant ID, the error message SHALL state: "A school with this name already exists. Please choose a different name."

---

## Testing Strategy

### Dual Testing Approach

This feature requires both **unit tests** (for specific examples and edge cases) and **property-based tests** (for universal properties across all inputs). Together, they provide comprehensive coverage.

### Property-Based Testing

**Library**: Use `fast_check` (Dart port) or `test_api` with custom generators for property-based testing.

**Configuration**: Each property test SHALL run a minimum of 100 iterations to ensure adequate input coverage.

**Tagging**: Each property test SHALL include a comment tag referencing the design document property:
```dart
// Feature: scholify-roadmap-tracker, Property 1: Wizard School Name Validation
test('wizard accepts non-empty school names', () {
  fc.assert(fc.property(fc.string(), (name) {
    final trimmed = name.trim();
    final isValid = wizardValidator.validateSchoolName(name);
    expect(isValid, equals(trimmed.isNotEmpty));
  }), numRuns: 100);
});
```

**Generators**: Custom generators SHALL be created for:
- Tenant records with varying plans, seat limits, expiry dates
- Audit log entries with different entity types and actors
- Date pairs for alert tier computation
- Filter criteria combinations
- CSV data with special characters (commas, quotes, newlines)

### Unit Testing

**Example-Based Tests**: Unit tests SHALL cover:
- Specific UI flows (wizard steps, impersonation banner)
- Integration points (PocketBase API calls, database transactions)
- Edge cases (empty lists, null values, boundary conditions)
- Error handling (rollback, validation errors, network failures)

**Widget Tests**: UI components SHALL be tested with Flutter widget tests:
- Onboarding wizard step navigation
- Tenant list filtering and search
- Audit log pagination
- Dashboard summary cards
- Impersonation banner visibility

**Integration Tests**: End-to-end flows SHALL be tested with integration tests:
- Complete onboarding wizard flow (create tenant → license → owner)
- Self-service signup flow (register → provision → sign in)
- Plan upgrade request flow (submit → review → approve/reject)
- Sync failure retry flow (fail → display → retry → succeed)

### Test Coverage Goals

- **Unit test coverage**: ≥ 80% line coverage for all service classes
- **Widget test coverage**: All user-facing pages and critical UI components
- **Property test coverage**: All 20 correctness properties from design document
- **Integration test coverage**: All multi-step workflows and external API interactions

### Testing Priorities

**HIGH PRIORITY** (must be tested before release):
- Property 4: Wizard atomic write (data integrity)
- Property 6: Audit log append-only invariant (compliance)
- Property 11: Seat limit enforcement boundary (revenue protection)
- Property 18: CSV serialization round-trip (data export correctness)

**MEDIUM PRIORITY** (should be tested before release):
- All validation properties (1, 2, 3, 13, 14, 15)
- All filtering properties (5, 8)
- All UI invariant properties (10, 19, 20)

**LOW PRIORITY** (can be tested post-release):
- Alert tier computation (9) - visual indicator, not critical
- Staleness check (17) - informational only

---

## Implementation Guidance

### Phase 1: Foundation (Week 1-2)

**Goal**: Establish data models, services, and core infrastructure

**Tasks**:
1. Create new Drift tables: `AuditLogEntries`, `PlanUpgradeRequestEntries`, `TenantBrandingEntries`
2. Run Drift code generation: `dart run build_runner build`
3. Implement `AuditLogService` with write interception
4. Implement `LicenseAlertService` with reactive alert computation
5. Implement `SeatLimitEnforcementService` with boundary checking
6. Implement `CSVExportService` with RFC 4180 compliance
7. Implement `ImpersonationService` with audit logging
8. Write unit tests for all services (target: 80% coverage)
9. Write property tests for validation logic (Properties 1-3, 13-15)

**Deliverables**:
- All new tables created and migrated
- All services implemented and tested
- Property tests passing for validation logic

### Phase 2: HIGH IMPACT Features (Week 3-4)

**Goal**: Implement tenant onboarding wizard, search/filtering, audit log, license alerts

**Tasks**:
1. Build `OnboardingWizardPage` with 3-step flow
2. Integrate wizard with `AuditLogService` for audit trail
3. Write widget tests for wizard UI
4. Write property tests for wizard atomicity (Property 4)
5. Enhance `TenantLicensingPage` with search field and filter chips
6. Implement filter logic with metamorphic properties (Property 5)
7. Write property tests for filter composition
8. Build `SuperadminAuditPage` with pagination and filtering
9. Write property tests for audit log invariants (Properties 6-8)
10. Integrate `LicenseAlertService` into `SuperadminDashboard`
11. Write property tests for alert tier computation (Property 9)
12. Add alert banners to dashboard UI

**Deliverables**:
- Onboarding wizard fully functional
- Tenant search and filtering working
- Audit log page with pagination
- License expiry alerts visible on dashboard
- All HIGH IMPACT property tests passing

### Phase 3: ARCHITECTURE / RELIABILITY Features (Week 5)

**Goal**: Implement PocketBase rules verification, sync failure visibility, seat limit enforcement

**Tasks**:
1. Create `bin/verify_pocketbase_rules.dart` script
2. Implement rules comparison logic against `docs/POCKETBASE_TENANT_RULES.md`
3. Write integration tests for rules verifier
4. Build `SyncFailurePage` with failed entry list
5. Add "Retry All" and "Dismiss" actions
6. Implement warning icon in `FoundationShell` app bar
7. Write property test for warning icon invariant (Property 10)
8. Integrate `SeatLimitEnforcementService` into `StudentEnrollmentPage`
9. Write property tests for seat limit enforcement (Properties 11-12)
10. Add error handling for `SeatLimitExceededException`

**Deliverables**:
- Rules verifier script executable
- Sync failure page functional
- Seat limit enforcement active
- All ARCHITECTURE property tests passing

### Phase 4: BUSINESS / GROWTH Features (Week 6-7)

**Goal**: Implement self-service signup, plan upgrade flow, branding, usage analytics

**Tasks**:
1. Build `SelfServiceSignupPage` with unauthenticated access
2. Implement `SignupService` with rollback on failure
3. Write integration tests for signup flow
4. Build `PlanUpgradePage` for school owners
5. Build upgrade request review UI for superadmin
6. Write property test for plan comparison (Property 14)
7. Build `BrandingSettingsPage` with logo upload
8. Implement logo encoding/decoding with base64
9. Write property tests for logo validation and round-trip (Properties 15-16)
10. Integrate branding into `FoundationShell` app bar
11. Build `UsageAnalyticsPage` with tenant metrics table
12. Add 6-month MAU time-series chart
13. Write property tests for staleness check and CSV round-trip (Properties 17-18)
14. Implement CSV export for usage analytics

**Deliverables**:
- Self-service signup functional
- Plan upgrade request flow working
- Per-tenant branding active
- Usage analytics page with export
- All BUSINESS property tests passing

### Phase 5: QUICK WINS Features (Week 8)

**Goal**: Implement tenant detail page, CSV export, impersonation, dashboard summary cards

**Tasks**:
1. Build `TenantDetailPage` with all tenant info
2. Add "Impersonate", "Edit License", "Suspend/Activate" actions
3. Implement CSV export for tenant list
4. Write property test for CSV RFC 4180 compliance (covered by Property 18)
5. Add "Impersonate" action to tenant list cards
6. Implement impersonation banner in `FoundationShell`
7. Write property test for banner invariant (Property 19)
8. Add 4 summary cards to `SuperadminDashboard`
9. Implement card value computation
10. Write property test for aggregation invariant (Property 20)

**Deliverables**:
- Tenant detail page functional
- CSV export working for tenant list
- Impersonation with banner active
- Dashboard summary cards displaying
- All QUICK WINS property tests passing

### Phase 6: Integration and Polish (Week 9-10)

**Goal**: End-to-end testing, bug fixes, documentation, deployment

**Tasks**:
1. Run full integration test suite
2. Fix any failing tests or bugs
3. Perform manual QA on all 11 requirements
4. Update user documentation with new features
5. Update developer documentation with new services and tables
6. Perform performance testing (search, filtering, CSV export)
7. Optimize slow queries with database indexes
8. Deploy to staging environment
9. Conduct UAT with superadmin and school owner test accounts
10. Deploy to production

**Deliverables**:
- All 20 property tests passing
- All integration tests passing
- All manual QA scenarios passing
- Documentation updated
- Production deployment complete

---

## Dependencies

### External Libraries

- **drift**: Local SQLite persistence (already in use)
- **pocketbase**: PocketBase Dart SDK (already in use)
- **file_picker**: File save dialog for CSV export (new)
- **csv**: CSV parsing and serialization (new)
- **intl**: Date formatting for alerts and audit log (already in use)
- **fast_check** or **test_api**: Property-based testing library (new)

### Internal Dependencies

- **TenantContext**: Active tenant and role state (already exists)
- **SyncEngine**: Background sync service (already exists)
- **AppLocalDatabase**: Drift database instance (already exists)
- **PocketbaseGateway**: HTTP client for PocketBase API (already exists)
- **ModuleAccessPolicy**: Feature flag resolution (already exists)

### PocketBase Collections

**New Collections**:
- `audit_logs`: Append-only audit trail
- `plan_upgrade_requests`: Upgrade request workflow
- `tenant_branding`: Per-tenant logo and display name

**Modified Collections**:
- `tenant_licenses`: No schema changes, but new queries for expiry alerts
- `tenant_usage_metrics`: No schema changes, but new queries for analytics

### Database Migrations

**Migration 1**: Add `AuditLogEntries` table
**Migration 2**: Add `PlanUpgradeRequestEntries` table
**Migration 3**: Add `TenantBrandingEntries` table

All migrations SHALL be backward-compatible (additive only, no breaking changes).

---

## Performance Considerations

### Search and Filtering

**Debouncing**: Search input SHALL be debounced by 300ms to avoid excessive re-renders.

**Indexing**: Drift tables SHALL have indexes on frequently queried columns:
- `TenantRecords`: `(tenant_id)`, `(updated_at DESC)`
- `AuditLogEntries`: `(tenant_id, timestamp DESC)`, `(entity_type, timestamp DESC)`, `(actor_id, timestamp DESC)`
- `TenantLicenseEntries`: `(tenant_id)`, `(expires_at)`, `(is_active)`

**Pagination**: Audit log SHALL be paginated at 50 entries per page to avoid loading large result sets.

### CSV Export

**Streaming**: For large tenant lists (>1000 rows), CSV export SHALL use streaming to avoid loading all data into memory at once.

**Background Processing**: CSV generation SHALL run on a background isolate to avoid blocking the UI thread.

### Sync Performance

**Batch Size**: Sync engine SHALL process sync queue in batches of 25 operations to balance throughput and responsiveness.

**Retry Backoff**: Failed sync operations SHALL use exponential backoff (1s, 2s, 4s, 8s, 16s, max 30s) to avoid overwhelming the server.

### Image Encoding

**Size Limit**: Logo images SHALL be limited to 2 MB to avoid excessive storage and network usage.

**Compression**: Consider adding client-side image compression before base64 encoding to reduce storage size (optional enhancement).

---

## Security Considerations

### Tenant Isolation

**PocketBase Rules**: All tenant-scoped collections SHALL enforce tenant isolation via PocketBase rules (see `docs/POCKETBASE_TENANT_RULES.md`).

**Client-Side Filtering**: Sync engine SHALL apply tenant scope filter on pull requests for non-superadmin contexts.

**Audit Trail**: All tenant-scoped write operations SHALL be logged to audit log with actor ID and tenant ID.

### Superadmin Privileges

**Role Verification**: Superadmin-only actions (create tenant, approve upgrade, impersonate) SHALL verify `isSuperAdmin` flag before execution.

**Impersonation Logging**: All impersonation events (start and end) SHALL be logged to audit log for compliance.

**Rules Verification**: PocketBase rules verifier SHALL be run regularly (e.g., weekly) to detect misconfigurations.

### Data Privacy

**PII Handling**: Audit log SHALL NOT store sensitive PII (passwords, payment info) in `changedFields` JSON. Only store field names and non-sensitive values.

**Logo Storage**: Tenant logos SHALL be stored as base64 strings in the database. Consider moving to object storage (e.g., S3) for production scale (optional enhancement).

### Input Validation

**Server-Side Validation**: All validation rules (email format, password length, seat limit) SHALL be enforced server-side in PocketBase collection rules, not just client-side.

**SQL Injection**: Drift parameterized queries SHALL be used for all database operations to prevent SQL injection.

**XSS Prevention**: All user-generated content (school names, display names, messages) SHALL be sanitized before rendering in UI.

---

## Deployment Strategy

### Database Migrations

**Migration Script**: Drift migrations SHALL be applied automatically on app startup via `MigrationStrategy`.

**Rollback Plan**: If a migration fails, the app SHALL display an error message and prevent further use until the migration is fixed.

### Feature Flags

**Gradual Rollout**: New features SHALL be gated behind feature flags in `TenantFeatureFlagEntries` to allow gradual rollout.

**Superadmin Control**: Superadmin SHALL be able to enable/disable features per tenant via the existing Feature Flags page.

### Monitoring

**Sync Metrics**: Track sync queue depth, failed operation count, and sync cycle duration.

**Alert Metrics**: Track count of tenants in each alert tier (warning30, alert14, urgent7, expired).

**Usage Metrics**: Track CSV export usage, impersonation frequency, and audit log query performance.

### Rollback Plan

**Database Rollback**: If a critical bug is discovered, roll back to previous app version. Database migrations are additive, so rollback is safe.

**Feature Disable**: If a specific feature is causing issues, disable it via feature flag without requiring a full rollback.

---

## Future Enhancements

### Post-MVP Improvements

1. **Email Notifications**: Send email alerts for license expiry (30d, 14d, 7d) instead of just in-app banners
2. **Webhook Integration**: Allow tenants to configure webhooks for audit log events
3. **Advanced Analytics**: Add more usage metrics (module-level engagement, user activity heatmaps)
4. **Bulk Operations**: Allow superadmin to bulk-update licenses (e.g., extend all expiring licenses by 30 days)
5. **Tenant Self-Service Portal**: Allow school owners to view their own usage metrics and billing history
6. **Logo CDN**: Move tenant logos from base64 in database to object storage with CDN for faster loading
7. **Audit Log Export**: Allow superadmin to export audit log to CSV for compliance reporting
8. **Plan Comparison Matrix**: Show feature comparison table when school owner requests plan upgrade
9. **Automated Seat Limit Warnings**: Notify school owner when seat utilization reaches 80%, 90%, 95%
10. **Multi-Language Support**: Localize all UI strings for international schools

---

## Conclusion

This design document provides a comprehensive technical blueprint for implementing 11 planned requirements across the Scholify platform. The design emphasizes:

- **Offline-first architecture** with Drift local persistence and async sync
- **Tenant isolation** enforced at database, sync, and PocketBase rule layers
- **Audit trail** for compliance and incident investigation
- **Property-based testing** for high-confidence correctness guarantees
- **Graceful error handling** with clear user feedback and retry mechanisms
- **Superadmin control plane** for cross-tenant management and support

The implementation is structured in 6 phases over 10 weeks, with clear deliverables and testing milestones at each phase. All 20 correctness properties are formally specified and will be validated with property-based tests running 100+ iterations each.

The design is ready for implementation. Developers should follow the phase-by-phase guidance, write tests first (TDD), and ensure all property tests pass before moving to the next phase.

