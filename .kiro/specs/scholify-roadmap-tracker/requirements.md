# Requirements Document — Scholify Roadmap Tracker

## Introduction

Scholify is a multi-tenant school management platform built with Flutter (desktop-first, web-capable),
Drift (offline-first local persistence), and PocketBase (remote backend). This document serves as the
authoritative roadmap tracker: it records every module that has already been shipped, and captures
structured requirements for every planned improvement — covering high-impact features, architecture
reliability work, business/growth capabilities, and quick wins.

The tracker is intended to be a living reference for the engineering team. Each planned item is expressed
as a formal requirement with EARS-pattern acceptance criteria and testability guidance so that
implementation and verification can proceed without ambiguity.

---

## Glossary

- **Superadmin**: The platform operator role with cross-tenant visibility and control.
- **Tenant**: A single school organisation provisioned on the platform, identified by a unique `tenant_id`.
- **School_Owner**: The primary administrator account for a Tenant, provisioned by the Superadmin.
- **License**: A `TenantLicenseEntry` record that binds a Tenant to a plan, seat limit, and expiry date.
- **Plan**: One of `starter`, `professional`, or `enterprise`; determines default module access.
- **Seat_Limit**: The maximum number of active students permitted under a License.
- **Feature_Flag**: A per-tenant boolean override stored in `TenantFeatureFlagEntries` that can enable or
  disable a module independently of the plan default.
- **Sync_Engine**: The background service that processes the outbox queue (`SyncQueueEntries`) and
  executes pull checkpoints against PocketBase.
- **Sync_Queue**: The `SyncQueueEntries` Drift table that holds pending push operations.
- **Audit_Log**: An append-only record of actor, action, target entity, and timestamp for every
  significant write operation.
- **Onboarding_Wizard**: A guided multi-step flow that creates a Tenant, issues a License, and
  provisions a School_Owner in a single session.
- **Impersonation**: A Superadmin capability to temporarily adopt a Tenant's context for support
  and debugging purposes without knowing the School_Owner's credentials.
- **Module_Access_Policy**: The `ModuleAccessPolicy` class that resolves the effective feature map
  from plan defaults and Feature_Flag overrides.
- **PocketBase_Rules**: Server-side collection access rules enforcing tenant isolation.
- **Drift**: The local SQLite ORM used for offline-first persistence.
- **Self_Service_Signup**: A flow allowing a new school to register and receive a starter Tenant
  without Superadmin intervention.

---

## Part A — Completed Modules (Baseline Record)

The following modules are fully implemented and tested. They are recorded here for traceability.
No new acceptance criteria are required; the existing test suite covers them.

| # | Module | Location |
|---|--------|----------|
| 1 | Auth and session bootstrap | `lib/core/auth`, `lib/features/auth` |
| 2 | Foundation shell and sync status | `lib/app` |
| 3 | Superadmin tenant licensing | `lib/features/superadmin` |
| 4 | School owner provisioning | `lib/features/superadmin` |
| 5 | Superadmin usage and billing monitor | `lib/features/superadmin` |
| 6 | Feature flags and plan-based module access control | `lib/features/superadmin`, `lib/app` |
| 7 | Notice board announcements | `lib/features/notices` |
| 8 | Class timetable management | `lib/features/timetable` |
| 9 | Transport routes management | `lib/features/transport` |
| 10 | Homework and daily assignments | `lib/features/homework` |
| 11 | Online learning catalog | `lib/features/online_learning` |
| 12 | Curriculum baseline (lessons, lesson plans, subjects, syllabus) | `lib/features/curriculum` |
| 13 | Library baseline | `lib/features/library` |
| 14 | Document Center baseline | `lib/features/documents` |
| 15 | Visitor and communication baseline | `lib/features/visitor_communication` |
| 16 | Notifications baseline | `lib/features/notifications` |
| 17 | Live classes baseline (Zoom + Gmeet) | `lib/features/live_classes` |
| 18 | Students directory | `lib/features/students` |
| 19 | Student guardians submodule | `lib/features/students` |
| 20 | Student enrollment status submodule | `lib/features/students` |
| 21 | Student class roll mapping submodule | `lib/features/students` |
| 22 | Attendance with student picker | `lib/features/attendance` |
| 23 | Fees invoice tracking | `lib/features/fees` |
| 24 | Exams scheduling and marks CRUD | `lib/features/exams` |
| 25 | Exam analytics dashboard | `lib/features/exams` |
| 26 | Homework submission and evaluation lifecycle | `lib/features/homework` |
| 27 | Online learning attempt and result lifecycle | `lib/features/online_learning` |

---

## Part B — Planned Requirements

Requirements are grouped by the team's priority classification. Each requirement carries EARS-pattern
acceptance criteria and a testability note.

---

### HIGH IMPACT

---

### Requirement H1: Tenant Onboarding Wizard

**User Story:** As a Superadmin, I want a single guided flow that creates a Tenant, issues a License,
and sends an owner invite email, so that I can provision a new school in one session without navigating
between three separate pages.

#### Acceptance Criteria

1. THE Onboarding_Wizard SHALL present steps in the fixed order: (1) Tenant identity, (2) License
   configuration, (3) School_Owner email invite.
2. WHEN the Superadmin completes step 1, THE Onboarding_Wizard SHALL validate that the school name is
   non-empty and that the derived `tenant_id` does not already exist in `TenantRecords`.
3. WHEN the Superadmin completes step 2, THE Onboarding_Wizard SHALL validate that the selected plan is
   one of `starter`, `professional`, or `enterprise`, and that the seat limit is a positive integer.
4. WHEN the Superadmin completes step 3, THE Onboarding_Wizard SHALL validate that the owner email
   contains an `@` character and a domain segment.
5. WHEN all three steps pass validation, THE Onboarding_Wizard SHALL atomically write a `TenantRecord`,
   a `TenantLicenseEntry`, and a `SchoolOwnerEntry` to the local Drift database and enqueue all three
   as `upsert` operations in the Sync_Queue.
6. IF any local write fails, THEN THE Onboarding_Wizard SHALL roll back all partial writes and display
   an error message identifying the failed step.
7. WHEN the wizard completes successfully, THE Onboarding_Wizard SHALL display a confirmation summary
   showing the tenant name, plan, seat limit, and owner email.
8. WHILE the wizard is saving, THE Onboarding_Wizard SHALL disable all navigation controls and show a
   progress indicator.

**Testability note:** Steps 2–6 are pure validation and local-write logic — property-based tests can
drive arbitrary school names, plans, and seat limits to verify invariants (duplicate detection, rollback
atomicity). Step 7 is an example-based UI test.

---

### Requirement H2: Tenant Search and Filtering

**User Story:** As a Superadmin, I want to search and filter the tenant list by name, plan, and
activation status, so that I can locate a specific school quickly when the list grows large.

#### Acceptance Criteria

1. THE Tenant_List_Page SHALL display a search field that filters tenants by school name using
   case-insensitive substring matching.
2. WHEN the search field is empty, THE Tenant_List_Page SHALL display all tenants ordered by
   `updated_at` descending.
3. WHEN the Superadmin types in the search field, THE Tenant_List_Page SHALL update the displayed list
   within 300 ms to show only tenants whose name contains the search string.
4. THE Tenant_List_Page SHALL provide filter chips for plan (`starter`, `professional`, `enterprise`,
   `all`) and activation status (`active`, `suspended`, `all`).
5. WHEN a plan filter chip is selected, THE Tenant_List_Page SHALL display only tenants whose
   `planCode` matches the selected value.
6. WHEN an activation filter chip is selected, THE Tenant_List_Page SHALL display only tenants whose
   `isActive` flag matches the selected value.
7. WHEN both a search string and a filter chip are active, THE Tenant_List_Page SHALL apply both
   conditions with logical AND.
8. IF the filtered result set is empty, THEN THE Tenant_List_Page SHALL display a message stating
   "No tenants match the current filters."

**Testability note:** Filtering logic is a pure function over a list — property-based tests can verify
that filter(all, criteria) ⊆ all, that applying no filters returns the full set, and that combined
filters are strictly more restrictive than individual filters (metamorphic property).

---

### Requirement H3: Audit Log

**User Story:** As a Superadmin, I want an audit log that records who did what and when for every
significant write operation, so that I can investigate incidents and demonstrate compliance.

#### Acceptance Criteria

1. THE Audit_Log SHALL record an entry for every write operation that mutates a `TenantRecord`,
   `TenantLicenseEntry`, `SchoolOwnerEntry`, `TenantFeatureFlagEntry`, or `StudentEnrollmentEntry`.
2. WHEN a write operation is performed, THE Audit_Log SHALL capture: actor user ID, actor role,
   entity type, entity ID, operation type (`create`, `update`, `delete`), timestamp (UTC), and a
   JSON snapshot of the changed fields.
3. THE Audit_Log SHALL be append-only; existing entries SHALL NOT be modified or deleted by any
   application code path.
4. THE Superadmin_Audit_Page SHALL display audit entries in reverse chronological order, paginated
   at 50 entries per page.
5. WHEN the Superadmin filters by entity type, THE Superadmin_Audit_Page SHALL display only entries
   whose `entityType` matches the selected value.
6. WHEN the Superadmin filters by actor, THE Superadmin_Audit_Page SHALL display only entries whose
   `actorId` matches the selected value.
7. IF the audit log table does not exist in the local Drift schema, THEN THE Sync_Engine SHALL create
   it during database migration before processing any sync operations.
8. THE Audit_Log SHALL be synced to PocketBase as a push-only entity; pull sync is not required.

**Testability note:** Append-only invariant is a strong property — tests can verify that the count of
audit entries never decreases after any sequence of write operations. The JSON snapshot field supports
round-trip property testing (serialize → deserialize → re-serialize produces identical output).

---

### Requirement H4: License Expiry Alerts

**User Story:** As a Superadmin, I want to receive in-app alerts when a tenant's license is approaching
expiry, so that I can act before a school loses access.

#### Acceptance Criteria

1. THE License_Alert_Service SHALL compute the number of days remaining until `licenseExpiresAt` for
   every active License on each app launch and after every sync cycle.
2. WHEN a License has 30 or fewer days remaining, THE Superadmin_Dashboard SHALL display a warning
   badge on the affected tenant card.
3. WHEN a License has 14 or fewer days remaining, THE Superadmin_Dashboard SHALL display an amber
   alert banner listing all affected tenant names and their exact expiry dates.
4. WHEN a License has 7 or fewer days remaining, THE Superadmin_Dashboard SHALL display a red urgent
   alert banner listing all affected tenant names and their exact expiry dates.
5. WHEN a License has already expired (`licenseExpiresAt` is in the past), THE Superadmin_Dashboard
   SHALL display the tenant as "Expired" and visually distinguish it from active tenants.
6. IF `licenseExpiresAt` is null for a License, THEN THE License_Alert_Service SHALL treat that
   License as having no expiry and SHALL NOT generate any alert for it.
7. THE License_Alert_Service SHALL recompute alert states without requiring a full app restart when
   the Superadmin manually triggers a sync.

**Testability note:** The day-threshold logic is a pure function of `(expiresAt, now)` — property-based
tests can drive arbitrary date pairs and verify that the correct alert tier is returned for every
partition (>30, 30, 14, 7, 0, past). Edge cases at exact boundaries (exactly 30, 14, 7 days) must be
covered.

---

### ARCHITECTURE / RELIABILITY

---

### Requirement A1: PocketBase Rules Enforcement Verification

**User Story:** As a developer, I want a verification utility that checks whether the live PocketBase
instance has the correct tenant-isolation rules applied to each collection, so that misconfigured rules
are detected before they cause a data leak.

#### Acceptance Criteria

1. THE Rules_Verifier SHALL check every collection listed in `docs/POCKETBASE_TENANT_RULES.md` against
   the live PocketBase Admin API.
2. WHEN a collection's `listRule`, `viewRule`, `createRule`, `updateRule`, or `deleteRule` does not
   match the expected pattern, THE Rules_Verifier SHALL report the collection name, rule type, expected
   value, and actual value.
3. WHEN all rules match, THE Rules_Verifier SHALL report a single "All rules verified" confirmation.
4. THE Rules_Verifier SHALL be executable as a standalone Dart script (not requiring a running Flutter
   app) using `dart run`.
5. IF the PocketBase Admin API is unreachable, THEN THE Rules_Verifier SHALL exit with a non-zero
   status code and print a descriptive connection error.
6. THE Rules_Verifier SHALL NOT modify any collection rules; it is read-only.

**Testability note:** Integration test with a local PocketBase instance. Not suitable for property-based
testing — use 2–3 representative examples (correct rule, wrong rule, missing collection).

---

### Requirement A2: Sync Failure Visibility

**User Story:** As a Superadmin or School_Owner, I want to see a list of sync operations that have
failed, including the error message and retry count, so that I can identify and resolve data sync
problems without guessing.

#### Acceptance Criteria

1. THE Sync_Failure_Page SHALL display all `SyncQueueEntries` where `retryCount` exceeds 0 and
   `syncedAt` is null, ordered by `updatedAt` descending.
2. WHEN a sync entry has failed, THE Sync_Failure_Page SHALL display: entity type, entity ID,
   operation, retry count, last error message, and last attempted timestamp.
3. THE Sync_Failure_Page SHALL provide a "Retry All" action that re-enqueues all displayed failed
   entries for immediate processing by the Sync_Engine.
4. THE Sync_Failure_Page SHALL provide a per-entry "Dismiss" action that removes the entry from the
   failed list without retrying it.
5. WHEN the Sync_Engine successfully processes a previously failed entry, THE Sync_Failure_Page SHALL
   remove that entry from the list within one sync cycle.
6. IF there are no failed sync entries, THEN THE Sync_Failure_Page SHALL display "All operations
   synced successfully."
7. THE Foundation_Shell SHALL display a persistent warning icon in the app bar when the count of
   failed sync entries is greater than zero.

**Testability note:** The filtering query (retryCount > 0 AND syncedAt IS NULL) is testable as a
repository unit test with example data. The "Retry All" idempotency is testable: retrying an already-
synced entry should not create a duplicate queue entry (idempotence property).

---

### Requirement A3: Seat Limit Enforcement

**User Story:** As a Superadmin, I want the platform to enforce the seat limit defined in a tenant's
license, so that a school cannot enroll more students than they have paid for.

#### Acceptance Criteria

1. WHEN a new `StudentEnrollmentEntry` is created for a Tenant, THE Enrollment_Repository SHALL query
   the count of active enrollments for that Tenant before persisting.
2. IF the active enrollment count equals or exceeds the Seat_Limit defined in the Tenant's License,
   THEN THE Enrollment_Repository SHALL reject the operation and return an error of type
   `SeatLimitExceededException`.
3. WHEN a `SeatLimitExceededException` is raised, THE Student_Enrollment_Page SHALL display a message
   stating "Seat limit reached. Contact your administrator to upgrade the plan."
4. THE Seat_Limit check SHALL use the locally cached `TenantLicenseEntry`; it SHALL NOT require a
   live network call.
5. IF the Tenant's License has no `seatLimit` set (null or zero), THEN THE Enrollment_Repository
   SHALL allow enrollment without restriction.
6. WHEN a student's enrollment status is changed to inactive or deleted, THE active enrollment count
   SHALL decrease accordingly so that the freed seat becomes available.

**Testability note:** The enforcement logic is a pure comparison — property-based tests can drive
arbitrary (currentCount, seatLimit) pairs and verify that rejection occurs if and only if
currentCount >= seatLimit. The boundary case (currentCount == seatLimit - 1 vs == seatLimit) must
be explicitly covered.

---

### BUSINESS / GROWTH

---

### Requirement B1: Self-Service Tenant Signup

**User Story:** As a school administrator, I want to register my school on Scholify without contacting
the platform operator, so that I can start using the platform immediately on the starter plan.

#### Acceptance Criteria

1. THE Self_Service_Signup_Page SHALL be accessible without authentication.
2. WHEN a visitor submits the signup form, THE Self_Service_Signup_Page SHALL collect: school name,
   owner full name, owner email address, and a password.
3. WHEN the form is submitted, THE Signup_Service SHALL validate that the email address is not already
   registered in PocketBase.
4. IF the email is already registered, THEN THE Signup_Service SHALL display "An account with this
   email already exists."
5. WHEN validation passes, THE Signup_Service SHALL create a PocketBase user account, a `TenantRecord`
   with `isActive = true`, and a `TenantLicenseEntry` with `planCode = 'starter'` and a default seat
   limit of 100.
6. WHEN provisioning completes, THE Signup_Service SHALL automatically sign the new user in and
   navigate to the Foundation Shell.
7. IF any provisioning step fails, THEN THE Signup_Service SHALL roll back all created records and
   display a descriptive error message.
8. THE Self_Service_Signup_Page SHALL enforce a minimum password length of 8 characters.

**Testability note:** Validation rules (email format, password length, duplicate detection) are pure
functions suitable for property-based testing. Provisioning rollback is an example-based integration
test.

---

### Requirement B2: Plan Upgrade Request Flow

**User Story:** As a School_Owner, I want to submit a plan upgrade request from within the app, so
that the Superadmin is notified and can action the upgrade without requiring an out-of-band email.

#### Acceptance Criteria

1. THE Plan_Upgrade_Page SHALL be accessible to School_Owner role users from the Foundation Shell
   settings area.
2. WHEN a School_Owner submits an upgrade request, THE Plan_Upgrade_Page SHALL capture: current plan,
   requested plan, and an optional message.
3. THE Plan_Upgrade_Page SHALL prevent submission if the requested plan is the same as or lower than
   the current plan.
4. WHEN a valid upgrade request is submitted, THE Upgrade_Request_Service SHALL persist a
   `PlanUpgradeRequestEntry` locally and enqueue it for sync to PocketBase.
5. WHEN the Superadmin opens the Superadmin Dashboard, THE Superadmin_Dashboard SHALL display a badge
   showing the count of pending upgrade requests.
6. WHEN the Superadmin approves an upgrade request, THE Upgrade_Request_Service SHALL update the
   Tenant's `TenantLicenseEntry` with the new plan code and mark the request as approved.
7. WHEN the Superadmin rejects an upgrade request, THE Upgrade_Request_Service SHALL mark the request
   as rejected and the School_Owner SHALL see the rejection status on next sync.
8. IF a Tenant already has a pending upgrade request, THEN THE Plan_Upgrade_Page SHALL display the
   pending request status instead of the submission form.

**Testability note:** Plan comparison logic (requested > current) is a pure function testable with
property-based tests over all plan pairs. State transitions (pending → approved/rejected) are
example-based.

---

### Requirement B3: Per-Tenant Branding

**User Story:** As a School_Owner, I want to set my school's name and logo within the app, so that
the platform reflects my school's identity for staff and students.

#### Acceptance Criteria

1. THE Branding_Settings_Page SHALL allow the School_Owner to upload a logo image (PNG or JPEG,
   maximum 2 MB) and set a display name.
2. WHEN a logo is uploaded, THE Branding_Service SHALL store the image as a base64-encoded string in
   `TenantBrandingEntry` locally and enqueue it for sync.
3. WHEN the Foundation Shell renders for a Tenant with a configured logo, THE Foundation_Shell SHALL
   display the tenant logo in the app bar in place of the default Scholify icon.
4. WHEN the Foundation Shell renders for a Tenant with a configured display name, THE Foundation_Shell
   SHALL display the tenant display name as the app title.
5. IF no branding is configured for a Tenant, THEN THE Foundation_Shell SHALL display the default
   Scholify branding.
6. WHEN a School_Owner removes the logo, THE Branding_Service SHALL delete the `TenantBrandingEntry`
   logo field and revert the shell to default branding.
7. THE Branding_Settings_Page SHALL reject images larger than 2 MB and display "Image must be under
   2 MB."

**Testability note:** File size validation is a pure function. Logo display toggling (configured vs
default) is an example-based widget test. Round-trip property: encode(decode(logoBytes)) == logoBytes.

---

### Requirement B4: Usage Analytics for Superadmin

**User Story:** As a Superadmin, I want to see per-tenant module usage statistics, so that I can
identify which features are most used and which tenants are underutilising the platform.

#### Acceptance Criteria

1. THE Usage_Analytics_Page SHALL display, for each Tenant, the count of active students, active
   staff, monthly active users, and storage consumed in GB.
2. THE Usage_Analytics_Page SHALL display a per-tenant module engagement summary showing which
   modules have had at least one write operation in the last 30 days.
3. WHEN the Superadmin selects a Tenant, THE Usage_Analytics_Page SHALL display a detail view with
   a time-series chart of monthly active users over the last 6 months.
4. THE Usage_Analytics_Page SHALL source data from `TenantUsageMetricEntries` which are populated
   by the existing pull sync from PocketBase.
5. WHEN usage data for a Tenant has not been synced in more than 24 hours, THE Usage_Analytics_Page
   SHALL display a "Data may be stale" indicator next to that tenant's row.
6. THE Usage_Analytics_Page SHALL allow the Superadmin to export the current view as a CSV file
   containing tenant name, plan, active students, active staff, MAU, and storage columns.

**Testability note:** The staleness check (now - lastSyncedAt > 24h) is a pure function testable with
property-based date pairs. CSV serialization supports a round-trip property: parse(serialize(rows))
produces equivalent rows.

---

### QUICK WINS

---

### Requirement Q1: Tenant Detail Page

**User Story:** As a Superadmin, I want a single page that shows all information about a tenant in
one place, so that I do not have to navigate between licensing, usage, and owner pages to answer a
support query.

#### Acceptance Criteria

1. THE Tenant_Detail_Page SHALL display: tenant name, tenant ID, plan, seat limit, activation status,
   license expiry date, owner email, active student count, active staff count, monthly active users,
   storage GB, outstanding amount, and overdue invoice count.
2. WHEN the Superadmin navigates to the Tenant_Detail_Page, THE page SHALL load all data from local
   Drift tables without requiring a network call.
3. THE Tenant_Detail_Page SHALL provide an "Impersonate" button that sets the active TenantContext
   to the selected Tenant with `isSuperAdmin = true`.
4. THE Tenant_Detail_Page SHALL provide an "Edit License" button that navigates to the existing
   Tenant_Licensing_Page pre-populated with the tenant's current values.
5. THE Tenant_Detail_Page SHALL provide a "Suspend / Activate" toggle that calls the existing
   `setTenantLicenseStatus` method.
6. WHEN the Tenant_Detail_Page is open and a sync cycle completes, THE page SHALL refresh its data
   automatically via the existing Drift stream.

**Testability note:** Data loading from Drift streams is covered by existing repository tests.
The impersonation action is an example-based widget test verifying TenantContext state after tap.

---

### Requirement Q2: Export Tenant List to CSV

**User Story:** As a Superadmin, I want to export the tenant list to a CSV file, so that I can share
it with stakeholders or import it into a spreadsheet for analysis.

#### Acceptance Criteria

1. THE Tenant_List_Page SHALL provide an "Export CSV" button visible only to Superadmin users.
2. WHEN the Superadmin taps "Export CSV", THE CSV_Export_Service SHALL generate a UTF-8 encoded CSV
   file with a header row and one data row per tenant.
3. THE CSV file SHALL contain the following columns in order: tenant_name, tenant_id, plan, seat_limit,
   is_active, license_expires_at, owner_email, active_students, outstanding_amount.
4. WHEN the CSV file is generated, THE CSV_Export_Service SHALL trigger a file-save dialog on desktop
   platforms and a share sheet on mobile platforms.
5. IF the tenant list is empty, THEN THE CSV_Export_Service SHALL generate a CSV file containing only
   the header row.
6. THE CSV_Export_Service SHALL escape any field value that contains a comma or double-quote character
   per RFC 4180.

**Testability note:** CSV serialization is a pure function — property-based tests can drive arbitrary
tenant lists (including names with commas, quotes, and Unicode) and verify RFC 4180 compliance.
Round-trip property: parse(serialize(tenants)) produces equivalent tenant records.

---

### Requirement Q3: Impersonate Tenant

**User Story:** As a Superadmin, I want to impersonate a tenant's context from the tenant list, so
that I can see exactly what the school's users see and diagnose issues without needing their
credentials.

#### Acceptance Criteria

1. THE Tenant_List_Page SHALL display an "Impersonate" action for each tenant row, visible only to
   Superadmin users.
2. WHEN the Superadmin taps "Impersonate" for a tenant, THE Impersonation_Service SHALL call
   `TenantContext.setTenant` with the selected `tenantId`, `tenantName`, `role = 'school_owner'`,
   and `isSuperAdmin = true`.
3. WHEN impersonation is active, THE Foundation_Shell SHALL display a persistent banner stating
   "Impersonating: [tenant name] — tap to exit."
4. WHEN the Superadmin taps the impersonation banner, THE Impersonation_Service SHALL restore the
   Superadmin's original TenantContext (no tenant selected, `isSuperAdmin = true`).
5. WHILE impersonation is active, THE Foundation_Shell SHALL render the module destinations
   appropriate for the impersonated tenant's plan and Feature_Flags.
6. THE Impersonation_Service SHALL record an Audit_Log entry when impersonation starts and when it
   ends, capturing the Superadmin actor ID and the impersonated tenant ID.

**Testability note:** TenantContext state transitions are example-based unit tests. The banner
visibility invariant (banner shown iff impersonation active) is a property testable over arbitrary
context states.

---

### Requirement Q4: Superadmin Dashboard Summary Cards

**User Story:** As a Superadmin, I want summary metric cards at the top of the dashboard showing
total tenants, active tenants, at-risk tenants, and tenants expiring soon, so that I can assess
platform health at a glance.

#### Acceptance Criteria

1. THE Superadmin_Dashboard SHALL display four summary cards: "Total Tenants", "Active", "At Risk",
   and "Expiring Soon (≤30 days)".
2. WHEN the dashboard loads, THE Superadmin_Dashboard SHALL compute card values from the local
   `TenantUsageBillingView` stream without requiring a network call.
3. THE "Total Tenants" card SHALL display the count of all `TenantLicenseEntries` regardless of
   status.
4. THE "Active" card SHALL display the count of `TenantLicenseEntries` where `isActive = true`.
5. THE "At Risk" card SHALL display the count of tenants where seat utilisation ≥ 90%, or
   `overdueInvoices > 0`, or `outstandingAmount > 0` — consistent with the existing `_isAtRisk`
   logic in `UsageBillingMonitorPage`.
6. THE "Expiring Soon" card SHALL display the count of active tenants whose `licenseExpiresAt` is
   within 30 days of the current date.
7. WHEN the underlying Drift stream emits a new value, THE Superadmin_Dashboard SHALL update all
   four card values within one frame.

**Testability note:** Each card's computation is a pure aggregation function over a list — property-
based tests can drive arbitrary tenant lists and verify that card values are consistent with the
underlying data (e.g., Active + Suspended == Total, At Risk ≤ Total).

---

## Part C — Correctness Properties Summary

The following table consolidates the key testability decisions across all planned requirements.

| Req | Criterion | Test Type | Rationale |
|-----|-----------|-----------|-----------|
| H1 | Wizard validation (name, plan, seats) | Property-based | Varies with input; pure logic |
| H1 | Atomic write + rollback | Example-based | Integration; rollback is binary |
| H2 | Filter logic (name, plan, status) | Property-based | Metamorphic: filtered ⊆ unfiltered |
| H3 | Audit log append-only invariant | Property-based | Count never decreases |
| H3 | JSON snapshot round-trip | Property-based | serialize → deserialize → serialize |
| H4 | Day-threshold alert tier | Property-based | Pure function of (expiresAt, now) |
| A1 | Rules verification | Integration (2–3 examples) | Tests external service, not our logic |
| A2 | Failed-entry filter query | Unit (examples) | Simple predicate |
| A2 | Retry idempotence | Property-based | f(x) = f(f(x)) |
| A3 | Seat limit enforcement | Property-based | Pure comparison; boundary cases |
| B1 | Signup validation (email, password) | Property-based | Pure functions |
| B2 | Plan comparison (requested > current) | Property-based | Pure ordering function |
| B3 | Logo size validation | Property-based | Pure function of byte length |
| B3 | Logo encode/decode round-trip | Property-based | decode(encode(x)) == x |
| B4 | Staleness check (now - lastSync > 24h) | Property-based | Pure date arithmetic |
| B4 | CSV round-trip | Property-based | parse(serialize(rows)) == rows |
| Q2 | CSV RFC 4180 compliance | Property-based | Arbitrary strings with commas/quotes |
| Q3 | Impersonation banner invariant | Property-based | Banner iff impersonation active |
| Q4 | Dashboard card aggregation | Property-based | Active + Suspended == Total |
