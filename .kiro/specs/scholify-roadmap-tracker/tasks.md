# Implementation Plan: Scholify Roadmap Tracker

## Overview

This implementation plan covers 11 planned features across 4 priority tiers for the Scholify multi-tenant school management platform. The plan is structured in 6 phases over 10 weeks, implementing database migrations, services, UI pages, property-based tests, and integration tests. All code will be written in Dart using Flutter for UI and Drift for local persistence.

**Feature Summary:**
- HIGH IMPACT: Tenant Onboarding Wizard, Tenant Search/Filtering, Audit Log, License Expiry Alerts
- ARCHITECTURE/RELIABILITY: PocketBase Rules Verification, Sync Failure Visibility, Seat Limit Enforcement
- BUSINESS/GROWTH: Self-Service Signup, Plan Upgrade Request Flow, Per-Tenant Branding, Usage Analytics
- QUICK WINS: Tenant Detail Page, Export Tenant List to CSV, Impersonate Tenant, Dashboard Summary Cards

## Tasks

### Phase 1: Foundation (Week 1-2)

- [x] 1. Create new Drift tables and generate code
  - [x] 1.1 Create AuditLogEntries table in Drift schema
    - Add table definition with columns: id, tenantId, actorId, actorRole, entityType, entityId, operation, changedFields, timestamp
    - Add indexes: (tenantId, timestamp DESC), (entityType, timestamp DESC), (actorId, timestamp DESC)
    - _Requirements: H3.1, H3.2_
  
  - [x] 1.2 Create PlanUpgradeRequestEntries table in Drift schema
    - Add table definition with columns: id, tenantId, currentPlan, requestedPlan, message, status, reviewedBy, createdAt, reviewedAt, updatedAt
    - Add indexes: (tenantId, status), (status, createdAt DESC)
    - _Requirements: B2.4_
  
  - [x] 1.3 Create TenantBrandingEntries table in Drift schema
    - Add table definition with columns: id, tenantId, displayName, logoBase64, updatedAt
    - Add index: (tenantId)
    - _Requirements: B3.2_
  
  - [x] 1.4 Run Drift code generation
    - Execute `dart run build_runner build --delete-conflicting-outputs`
    - Verify generated DAO classes compile without errors
    - _Requirements: H3.1, B2.4, B3.2_

- [x] 2. Implement core services
  - [x] 2.1 Implement AuditLogService
    - Create service class with logWrite method
    - Integrate with TenantContext to capture actor information
    - Generate JSON snapshot of changed fields
    - Write AuditLogEntry to Drift and enqueue for sync
    - _Requirements: H3.1, H3.2_
  
  - [x] 2.2 Write property test for AuditLogService
    - **Property 6: Audit log append-only invariant**
    - **Property 7: Audit log entry completeness**
    - **Validates: Requirements H3.2, H3.3**
  
  - [x] 2.3 Implement LicenseAlertService
    - Create service class with watchAlerts and computeAlerts methods
    - Implement alert tier computation logic (30d, 14d, 7d, expired)
    - Provide reactive stream of alert states
    - _Requirements: H4.1, H4.2, H4.3, H4.4, H4.5_
  
  - [x] 2.4 Write property test for LicenseAlertService
    - **Property 9: License expiry alert tier computation**
    - **Validates: Requirements H4.1, H4.2, H4.3, H4.4, H4.5, H4.6**
  
  - [x] 2.5 Implement SeatLimitEnforcementService
    - Create service class with checkSeatLimit method
    - Query active enrollment count and compare against license seat limit
    - Throw SeatLimitExceededException when limit reached
    - _Requirements: A3.1, A3.2_
  
  - [x] 2.6 Write property test for SeatLimitEnforcementService
    - **Property 11: Seat limit enforcement boundary**
    - **Property 12: Enrollment count consistency**
    - **Validates: Requirements A3.2, A3.6**
  
  - [x] 2.7 Implement CSVExportService
    - Create service class with exportTenantList method
    - Serialize tenant list to RFC 4180 compliant CSV
    - Escape commas, quotes, and newlines per spec
    - Trigger platform-specific file save dialog
    - _Requirements: Q2.2, Q2.3, Q2.6_
  
  - [x] 2.8 Write property test for CSVExportService
    - **Property 18: CSV serialization round-trip**
    - **Validates: Requirements B4.7, Q2.6**
  
  - [x] 2.9 Implement ImpersonationService
    - Create service class with startImpersonation and endImpersonation methods
    - Set TenantContext to impersonated tenant with isSuperAdmin=true
    - Log impersonation start/end to audit log
    - Provide banner state for UI
    - _Requirements: Q3.2, Q3.4, Q3.6_
  
  - [x] 2.10 Write property test for ImpersonationService
    - **Property 19: Impersonation banner invariant**
    - **Validates: Requirements Q3.3**

- [-] 3. Write validation property tests
  - [x] 3.1 Write property test for wizard school name validation
    - **Property 1: Wizard school name validation**
    - **Validates: Requirements H1.2**
  
  - [x] 3.2 Write property test for wizard plan and seat limit validation
    - **Property 2: Wizard plan and seat limit validation**
    - **Validates: Requirements H1.3**
  
  - [x] 3.3 Write property test for wizard email validation
    - **Property 3: Wizard email validation**
    - **Validates: Requirements H1.4**
  
  - [x] 3.4 Write property test for signup password validation
    - **Property 13: Signup password length validation**
    - **Validates: Requirements B1.8**
  
  - [x] 3.5 Write property test for plan upgrade comparison
    - **Property 14: Plan upgrade comparison**
    - **Validates: Requirements B2.3**
  
  - [x] 3.6 Write property test for logo file size validation
    - **Property 15: Logo file size validation**
    - **Validates: Requirements B3.7**
  
  - [x] 3.7 Write property test for logo encoding round-trip
    - **Property 16: Logo encoding round-trip**
    - **Validates: Requirements B3.8**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

### Phase 2: HIGH IMPACT Features (Week 3-4)

- [ ] 5. Implement Tenant Onboarding Wizard (H1)
  - [x] 5.1 Create OnboardingWizardPage with 3-step flow
    - Build step 1: Tenant identity (school name input, tenant_id derivation)
    - Build step 2: License configuration (plan dropdown, seat limit input)
    - Build step 3: Owner email (email input, validation)
    - Add step navigation controls and progress indicator
    - _Requirements: H1.1, H1.2, H1.3, H1.4_
  
  - [x] 5.2 Implement wizard validation logic
    - Validate school name is non-empty and tenant_id is unique
    - Validate plan is one of starter/professional/enterprise
    - Validate seat limit is positive integer
    - Validate email contains @ and domain segment
    - _Requirements: H1.2, H1.3, H1.4_
  
  - [x] 5.3 Implement wizard atomic write with transaction
    - Begin Drift transaction
    - Insert TenantRecord, TenantLicenseEntry, SchoolOwnerEntry
    - Enqueue 3 sync operations
    - Commit transaction or rollback on failure
    - _Requirements: H1.5, H1.6_
  
  - [x] 5.4 Integrate wizard with AuditLogService
    - Log tenant creation to audit log
    - Log license issuance to audit log
    - Log owner provisioning to audit log
    - _Requirements: H3.1_
  
  - [x] 5.5 Write property test for wizard atomic write
    - **Property 4: Wizard atomic write**
    - **Validates: Requirements H1.5**
  
  - [x] 5.6 Write widget tests for wizard UI
    - Test step navigation and validation error display
    - Test confirmation summary display
    - Test progress indicator during save
    - _Requirements: H1.7, H1.8_

- [ ] 6. Implement Tenant Search and Filtering (H2)
  - [x] 6.1 Enhance TenantLicensingPage with search field
    - Add search text field with debouncing (300ms)
    - Implement case-insensitive substring matching
    - Update tenant list reactively on search input
    - _Requirements: H2.1, H2.3_
  
  - [x] 6.2 Add filter chips for plan and status
    - Add plan filter chips (All, Starter, Professional, Enterprise)
    - Add status filter chips (All, Active, Suspended)
    - Implement filter chip selection logic
    - _Requirements: H2.4, H2.5, H2.6_
  
  - [x] 6.3 Implement combined filter logic
    - Apply search query AND plan filter AND status filter
    - Display empty state message when no results
    - _Requirements: H2.7, H2.8_
  
  - [x] 6.4 Write property test for filter composition
    - **Property 5: Tenant filter composition (metamorphic)**
    - **Validates: Requirements H2.1, H2.5, H2.6, H2.7**

- [ ] 7. Implement Audit Log (H3)
  - [x] 7.1 Create SuperadminAuditPage with pagination
    - Build audit log list view with 50 entries per page
    - Display: timestamp, actor, entity type, entity ID, operation, changed fields
    - Implement pagination controls
    - _Requirements: H3.4_
  
  - [x] 7.2 Add audit log filtering
    - Add entity type filter dropdown
    - Add actor filter dropdown
    - Implement filter query logic
    - _Requirements: H3.5, H3.6_
  
  - [x] 7.3 Integrate audit logging into write operations
    - Hook AuditLogService into TenantRecord writes
    - Hook AuditLogService into TenantLicenseEntry writes
    - Hook AuditLogService into SchoolOwnerEntry writes
    - Hook AuditLogService into TenantFeatureFlagEntry writes
    - Hook AuditLogService into StudentEnrollmentEntry writes
    - _Requirements: H3.1_
  

- [ ] 8. Implement License Expiry Alerts (H4)
  - [x] 8.1 Integrate LicenseAlertService into SuperadminDashboard
    - Call computeAlerts on app launch and after sync
    - Display warning badges on tenant cards (30d)
    - Display amber alert banner (14d)
    - Display red urgent alert banner (7d)
    - Display "Expired" status for past expiry dates
    - _Requirements: H4.1, H4.2, H4.3, H4.4, H4.5_
  
  - [x] 8.2 Implement alert banner UI components
    - Build amber banner for 14-day alerts
    - Build red banner for 7-day alerts
    - List affected tenant names and expiry dates
    - _Requirements: H4.3, H4.4_
  
  - [x] 8.3 Add manual sync trigger for alert refresh
    - Recompute alerts on manual sync without app restart
    - _Requirements: H4.7_

- [ ] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

### Phase 3: ARCHITECTURE / RELIABILITY Features (Week 5)

- [ ] 10. Implement PocketBase Rules Verification (A1)
  - [x] 10.1 Create bin/verify_pocketbase_rules.dart script
    - Load expected rules from docs/POCKETBASE_TENANT_RULES.md
    - Query PocketBase Admin API for each collection
    - Compare listRule, viewRule, createRule, updateRule, deleteRule
    - Print mismatches with collection name, rule type, expected, actual
    - Exit 0 if all match, exit 1 if any mismatch
    - _Requirements: A1.1, A1.2, A1.3, A1.4_
  
  - [x] 10.2 Write integration test for rules verifier
    - Test with local PocketBase instance
    - Test correct rule scenario
    - Test wrong rule scenario
    - Test connection error scenario
    - _Requirements: A1.5, A1.6_

- [ ] 11. Implement Sync Failure Visibility (A2)
  - [x] 11.1 Create SyncFailurePage with failed entry list
    - Query SyncQueueEntries where retryCount > 0 AND syncedAt IS NULL
    - Display: entity type, entity ID, operation, retry count, error message, timestamp
    - Order by updatedAt DESC
    - _Requirements: A2.1, A2.2_
  
  - [x] 11.2 Add "Retry All" and "Dismiss" actions
    - Implement "Retry All" button to re-enqueue all failed entries
    - Implement per-entry "Dismiss" button to remove from queue
    - Display "All operations synced successfully" when no failures
    - _Requirements: A2.3, A2.4, A2.6_
  
  - [x] 11.3 Add warning icon to FoundationShell app bar
    - Display persistent warning icon when failed entry count > 0
    - Navigate to SyncFailurePage on icon tap
    - _Requirements: A2.7_
  
  - [x] 11.4 Write property test for warning icon invariant
    - **Property 10: Sync failure warning icon invariant**
    - **Validates: Requirements A2.7**
  
  - [x] 11.5 Write unit test for retry idempotence
    - Verify retrying already-synced entry doesn't create duplicate
    - _Requirements: A2.3_

- [ ] 12. Implement Seat Limit Enforcement (A3)
  - [x] 12.1 Integrate SeatLimitEnforcementService into StudentEnrollmentPage
    - Call checkSeatLimit before inserting StudentEnrollmentEntry
    - Catch SeatLimitExceededException and display error message
    - Display message: "Seat limit reached. Contact your administrator to upgrade the plan."
    - Include current count and limit in error message
    - _Requirements: A3.1, A3.2, A3.3_
  
  - [x] 12.2 Write unit test for seat limit with null/zero handling
    - Test that null or zero seatLimit allows unrestricted enrollment
    - _Requirements: A3.5_
  
  - [x] 12.3 Write integration test for seat count decrease on delete
    - Verify freed seat becomes available after enrollment deletion
    - _Requirements: A3.6_

- [ ] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

### Phase 4: BUSINESS / GROWTH Features (Week 6-7)

- [x] 14. Implement Self-Service Tenant Signup (B1)
  - [x] 14.1 Create SelfServiceSignupPage (unauthenticated)
    - Build signup form with: school name, owner full name, owner email, password
    - Make page accessible without authentication
    - _Requirements: B1.1, B1.2_
  
  - [x] 14.2 Implement SignupService with validation
    - Validate email is not already registered in PocketBase
    - Validate password length >= 8 characters
    - Display "An account with this email already exists" on duplicate
    - _Requirements: B1.3, B1.4, B1.8_
  
  - [x] 14.3 Implement signup provisioning with rollback
    - Create PocketBase user account
    - Create TenantRecord with isActive=true
    - Create TenantLicenseEntry with planCode='starter', seatLimit=100
    - Auto-sign-in user and navigate to Foundation Shell
    - Rollback all records on failure and display error
    - _Requirements: B1.5, B1.6, B1.7_
  
  - [ ] 14.4 Write integration test for signup flow
    - Test successful signup end-to-end
    - Test rollback on failure
    - _Requirements: B1.7_

- [x] 15. Implement Plan Upgrade Request Flow (B2)
  - [x] 15.1 Create PlanUpgradePage for school owners
    - Display current plan (read-only)
    - Add requested plan dropdown (only higher plans)
    - Add optional message textarea
    - Add "Submit Request" button
    - _Requirements: B2.1, B2.2_
  
  - [x] 15.2 Implement upgrade request submission
    - Validate requested plan > current plan
    - Insert PlanUpgradeRequestEntry with status='pending'
    - Enqueue sync operation
    - Display confirmation message
    - Display pending request status if already exists
    - _Requirements: B2.3, B2.4, B2.8_
  
  - [x] 15.3 Build upgrade request review UI for superadmin
    - Add "Upgrade Requests" badge to SuperadminDashboard
    - List pending requests with tenant name, plans, message
    - Add "Approve" button to update license and set status='approved'
    - Add "Reject" button to set status='rejected'
    - _Requirements: B2.5, B2.6, B2.7_
  
  - [ ] 15.4 Write unit test for plan comparison logic
    - Test all plan pairs (starter, professional, enterprise)
    - Verify upgrade/downgrade/same detection
    - _Requirements: B2.3_

- [x] 16. Implement Per-Tenant Branding (B3)
  - [x] 16.1 Create BrandingSettingsPage for school owners
    - Add display name input (pre-filled with tenant name)
    - Add logo upload button (PNG/JPEG, max 2MB)
    - Add logo preview
    - Add "Save" and "Remove Logo" buttons
    - _Requirements: B3.1_
  
  - [x] 16.2 Implement branding save logic
    - Validate image size <= 2MB
    - Encode image to base64
    - Upsert TenantBrandingEntry
    - Enqueue sync operation
    - Notify TenantContext listeners to refresh shell
    - Display "Image must be under 2 MB" on size violation
    - _Requirements: B3.2, B3.7_
  
  - [ ] 16.3 Integrate branding into FoundationShell app bar
    - Display tenant logo if configured, else default Scholify icon
    - Display tenant display name if configured, else "Scholify"
    - Handle logo removal to revert to default
    - _Requirements: B3.3, B3.4, B3.5, B3.6_
  
  - [ ] 16.4 Write widget test for branding display toggle
    - Test configured vs default branding rendering
    - _Requirements: B3.3, B3.4, B3.5_

- [x] 17. Implement Usage Analytics for Superadmin (B4)
  - [x] 17.1 Create UsageAnalyticsPage with tenant metrics table
    - Display columns: Tenant Name, Plan, Active Students, Active Staff, MAU, Storage GB, Module Engagement
    - Source data from TenantUsageMetricEntries
    - _Requirements: B4.1, B4.2, B4.4_
  
  - [x] 17.2 Add staleness indicator
    - Check if updatedAt > 24h ago
    - Display "⚠ Data may be stale" next to tenant row
    - _Requirements: B4.5_
  
  - [ ] 17.3 Write property test for staleness check
    - **Property 17: Usage data staleness check**
    - **Validates: Requirements B4.5**
  
  - [ ] 17.4 Add tenant detail view with MAU time-series chart
    - Build detail view on tenant selection
    - Display 6-month MAU time-series chart
    - _Requirements: B4.3_
  
  - [x] 17.5 Implement module engagement summary
    - Query AuditLogEntries for distinct entity types with writes in last 30 days
    - Display module engagement count per tenant
    - _Requirements: B4.2_
  
  - [x] 17.6 Add CSV export for usage analytics
    - Implement "Export CSV" button
    - Include columns: tenant name, plan, active students, active staff, MAU, storage
    - _Requirements: B4.6_

- [ ] 18. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

### Phase 5: QUICK WINS Features (Week 8)

- [x] 19. Implement Tenant Detail Page (Q1)
  - [x] 19.1 Create TenantDetailPage with comprehensive info
    - Display: tenant name, tenant ID, plan, seat limit, activation status, license expiry, owner email
    - Display: active student count, active staff count, MAU, storage GB, outstanding amount, overdue invoices
    - Load all data from local Drift tables without network call
    - _Requirements: Q1.1, Q1.2_
  
  - [x] 19.2 Add action buttons to TenantDetailPage
    - Add "Impersonate" button to set TenantContext with isSuperAdmin=true
    - Add "Edit License" button to navigate to TenantLicensingPage
    - Add "Suspend / Activate" toggle to call setTenantLicenseStatus
    - _Requirements: Q1.3, Q1.4, Q1.5_
  
  - [ ] 19.3 Write widget test for impersonation action
    - Verify TenantContext state after impersonate button tap
    - _Requirements: Q1.3_

- [x] 20. Implement Export Tenant List to CSV (Q2)
  - [x] 20.1 Add "Export CSV" button to TenantListPage
    - Make button visible only to Superadmin users
    - _Requirements: Q2.1_
  
  - [x] 20.2 Implement CSV export with RFC 4180 compliance
    - Generate UTF-8 encoded CSV with header row
    - Include columns: tenant_name, tenant_id, plan, seat_limit, is_active, license_expires_at, owner_email, active_students, outstanding_amount
    - Escape fields with commas, quotes, newlines per RFC 4180
    - Trigger file-save dialog on desktop, share sheet on mobile
    - Handle empty tenant list (header row only)
    - _Requirements: Q2.2, Q2.3, Q2.4, Q2.5, Q2.6_

- [x] 21. Implement Impersonate Tenant (Q3)
  - [x] 21.1 Add "Impersonate" action to tenant list rows
    - Make action visible only to Superadmin users
    - Call ImpersonationService.startImpersonation on tap
    - Set TenantContext with tenantId, tenantName, role='school_owner', isSuperAdmin=true
    - _Requirements: Q3.1, Q3.2_
  
  - [x] 21.2 Build impersonation banner in FoundationShell
    - Display persistent banner: "Impersonating: [tenant name] — tap to exit"
    - Call ImpersonationService.endImpersonation on banner tap
    - Restore Superadmin's original TenantContext
    - _Requirements: Q3.3, Q3.4_
  
  - [x] 21.3 Render module destinations for impersonated tenant
    - Display modules appropriate for tenant's plan and feature flags
    - _Requirements: Q3.5_
  
  - [ ] 21.4 Write unit test for TenantContext state transitions
    - Test impersonation start and end state changes
    - _Requirements: Q3.2, Q3.4_

- [x] 22. Implement Superadmin Dashboard Summary Cards (Q4)
  - [x] 22.1 Add 4 summary cards to SuperadminDashboard
    - Build "Total Tenants" card (count of all TenantLicenseEntries)
    - Build "Active" card (count where isActive=true)
    - Build "At Risk" card (count where seat utilization >= 90% OR overdueInvoices > 0 OR outstandingAmount > 0)
    - Build "Expiring Soon" card (count where active AND expiresAt <= now + 30 days)
    - _Requirements: Q4.1, Q4.2, Q4.3, Q4.4, Q4.5, Q4.6_
  
  - [x] 22.2 Implement reactive card value updates
    - Compute card values from TenantUsageBillingView stream
    - Update all cards within one frame on stream emit
    - _Requirements: Q4.7_
  
  - [ ] 22.3 Write property test for dashboard aggregation invariant
    - **Property 20: Dashboard summary aggregation invariant**
    - **Validates: Requirements Q4.8**

- [ ] 23. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

### Phase 6: Integration and Polish (Week 9-10)

- [ ] 24. End-to-end integration testing
  - [ ] 24.1 Write integration test for complete onboarding wizard flow
    - Test: create tenant → license → owner → verify all records created
    - _Requirements: H1.5_
  
  - [ ] 24.2 Write integration test for self-service signup flow
    - Test: register → provision → sign in → verify tenant created
    - _Requirements: B1.5, B1.6_
  
  - [ ] 24.3 Write integration test for plan upgrade request flow
    - Test: submit → review → approve/reject → verify status update
    - _Requirements: B2.4, B2.6, B2.7_
  
  - [ ] 24.4 Write integration test for sync failure retry flow
    - Test: fail → display → retry → succeed → verify entry removed
    - _Requirements: A2.3, A2.5_

- [x] 25. Performance optimization
  - [x] 25.1 Add database indexes for frequently queried columns
    - Add indexes to TenantRecords: (tenant_id), (updated_at DESC)
    - Add indexes to AuditLogEntries: (tenant_id, timestamp DESC), (entity_type, timestamp DESC), (actor_id, timestamp DESC)
    - Add indexes to TenantLicenseEntries: (tenant_id), (expires_at), (is_active)
    - _Requirements: Performance considerations from design_
  
  - [x] 25.2 Implement search debouncing
    - Add 300ms debounce to tenant search field
    - _Requirements: H2.3_
  
  - [x] 25.3 Optimize CSV export for large datasets
    - Implement streaming for tenant lists > 1000 rows
    - Run CSV generation on background isolate
    - _Requirements: Performance considerations from design_

- [ ] 26. Documentation and deployment
  - [ ] 26.1 Update user documentation
    - Document onboarding wizard flow
    - Document tenant search and filtering
    - Document audit log usage
    - Document license expiry alerts
    - Document sync failure visibility
    - Document self-service signup
    - Document plan upgrade request flow
    - Document per-tenant branding
    - Document usage analytics
    - Document impersonation feature
  
  - [ ] 26.2 Update developer documentation
    - Document new Drift tables and migrations
    - Document new services (AuditLogService, LicenseAlertService, etc.)
    - Document property-based testing approach
    - Update architecture diagrams
  
  - [ ] 26.3 Manual QA for all 11 requirements
    - Test H1: Tenant Onboarding Wizard
    - Test H2: Tenant Search and Filtering
    - Test H3: Audit Log
    - Test H4: License Expiry Alerts
    - Test A1: PocketBase Rules Verification
    - Test A2: Sync Failure Visibility
    - Test A3: Seat Limit Enforcement
    - Test B1: Self-Service Tenant Signup
    - Test B2: Plan Upgrade Request Flow
    - Test B3: Per-Tenant Branding
    - Test B4: Usage Analytics
    - Test Q1: Tenant Detail Page
    - Test Q2: Export Tenant List to CSV
    - Test Q3: Impersonate Tenant
    - Test Q4: Dashboard Summary Cards
  
  - [ ] 26.4 Deploy to staging environment
    - Run database migrations
    - Deploy Flutter web build
    - Verify all features work in staging
  
  - [ ] 26.5 Conduct UAT with test accounts
    - Test with superadmin account
    - Test with school owner account
    - Verify cross-tenant isolation
  
  - [ ] 26.6 Deploy to production
    - Run database migrations
    - Deploy Flutter web build
    - Monitor sync metrics and alert metrics
    - Verify no errors in production logs

- [ ] 27. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional property-based tests and integration tests that can be skipped for faster MVP
- Each task references specific requirements for traceability (e.g., H1.2, B3.7, Q4.8)
- Checkpoints ensure incremental validation at the end of each phase
- Property tests validate universal correctness properties with 100+ iterations each
- Unit tests validate specific examples and edge cases
- All code will be written in Dart using Flutter for UI and Drift for local persistence
- The implementation follows the 6-phase plan from the design document over 10 weeks
- Database migrations are additive and backward-compatible
- All 20 correctness properties from the design document are covered by property tests
