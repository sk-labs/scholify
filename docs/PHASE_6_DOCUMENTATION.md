# Scholify Phase 6 — Developer Documentation & Deployment Runbook

Feature: `scholify-roadmap-tracker`
Covers: Task 26.1 (user docs), 26.2 (developer docs), 26.4/26.5/26.6 (deployment ops).

## 1. Scope of This Document

Phase 6 closes out the roadmap with documentation and deployment operations.
Per project instruction, **testing tasks (24, 27) are skipped**. Performance
optimization (Task 25) is already implemented (see section 4).

All per-feature user guides already live as `README_*.md` files next to their
code (see section 2). This document consolidates the developer-facing overview,
the data model, services, architecture notes, and the deployment runbook so a
fresh contributor can run and ship the app.

---

## 2. Feature Map (User-facing documentation index)

Each feature has an inline README next to its code:

| Feature                    | Requirement set | Guide                                        | Entry point                                   |
|----------------------------|-----------------|----------------------------------------------|-----------------------------------------------|
| Tenant Onboarding Wizard   | H1              | `lib/features/superadmin/presentation/README_ONBOARDING_WIZARD.md` | Superadmin Dashboard → "Tenant Onboarding Wizard" |
| Tenant Search & Filtering  | H2              | inline in `tenant_licensing_page.dart`      | Superadmin Dashboard → "Tenant Licensing"     |
| Audit Log                  | H3              | `lib/features/superadmin/README_AUDIT.md` (inline) | Superadmin Dashboard → "Audit Log"          |
| License Expiry Alerts      | H4              | inline banners in `superadmin_dashboard_page.dart` | Superadmin Dashboard (top alerts)             |
| PocketBase Rules Verify    | A1              | `bin/verify_pocketbase_rules.dart`           | CLI script                                    |
| Sync Failure Visibility    | A2              | `lib/features/sync/presentation/README_SYNC_FAILURE_PAGE.md` | Foundation app bar warning icon             |
| Seat Limit Enforcement     | A3              | inline in `student_enrollment_page.dart`     | Students → Enrollment                         |
| Self-Service Signup        | B1              | `lib/features/auth/README_SELF_SERVICE_SIGNUP.md` | Sign-in → "Create a school account"           |
| Plan Upgrade Request       | B2              | `lib/features/plan_upgrade/README_PLAN_UPGRADE_REQUEST.md` | Foundation → "Request Plan Upgrade"; Superadmin → "Plan Upgrade Requests" |
| Per-Tenant Branding        | B3              | `lib/features/branding/README_TENANT_BRANDING.md` | Foundation → "Branding Settings"              |
| Usage Analytics            | B4              | `README_USAGE_ANALYTICS.md` (inline)         | Superadmin Dashboard → "Usage Analytics"       |
| Tenant Detail Page         | Q1              | `lib/features/tenant_detail/README_TENANT_DETAIL.md` | Tenant list → "Details"                        |
| Export Tenant List (CSV)   | Q2              | inline in `tenant_licensing_page.dart`       | Tenant Licensing → download icon              |
| Impersonate Tenant         | Q3              | `lib/features/impersonation/README_IMPERSONATE_TENANT.md` | Tenant list → "Impersonate"; banner in shell |
| Dashboard Summary Cards    | Q4              | `lib/features/dashboard/README_DASHBOARD_SUMMARY_CARDS.md` | Superadmin Dashboard (top)                  |

---

## 3. Architecture Overview

Layered Flutter app, desktop-first (Windows/macOS) with a PocketBase remote and
a local Drift (SQLite) cache. All writes go to the local DB and are enqueued to
a sync queue; the sync engine pushes them to PocketBase when online.

```
UI (lib/features/*/presentation)
     │  reads / writes
     ▼
Drift database (AppLocalDatabase — lib/core/database/local_database.dart)
     │  watch() streams / queries
     ▼
Core services (lib/core/services) + Sync Engine (lib/core/sync)
     │  enqueue/consume
     ▼
PocketBase Gateway (lib/core/remote/pocketbase_gateway.dart)
```

Key runtime objects (built in `lib/bootstrap.dart`, exposed via `AppRuntime`):
- `AppLocalDatabase` — Drift DB, all tables + `watch*` streams + indexes.
- `TenantContext` — current tenant, role, superadmin flag, branding.
- `SessionManager` — auth state; drives `ScholifyApp` shell routing.
- `SyncEngine` — queue, background sync, streaming CSV export support.
- `PocketbaseGateway` — remote API client.

---

## 4. Database Schema & Migration Notes

All tables live in `local_database.dart`. Migrations are additive and
backward-compatible so existing installs are preserved.

Tables added by this roadmap:
- `audit_log_entries` — write audit trail (H3).
- `plan_upgrade_request_entries` — tenant upgrade requests (B2).
- `tenant_branding_entries` — per-tenant logo/display-name (B3).
- `tenant_usage_metric_entries` — monthly usage for the MAU chart (B4).

Indexes (Task 25.1, in `_createTables`/migrations):
- `tenant_records(id)`, `tenant_records(updated_at DESC)`
- `tenant_license_entries(tenant_id)`, `(expires_at)`, `(is_active)`
- `audit_log_entries(tenant_id, timestamp DESC)`, `(entity_type, timestamp DESC)`, `(actor_id, timestamp DESC)`
- `plan_upgrade_request_entries(tenant_id, status)`, `(status, created_at DESC)`
- `tenant_branding_entries(tenant_id)`

New services (in `lib/core/services/`):
- `AuditLogService`, `LicenseAlertService`, `SeatLimitEnforcementService`,
  `CSVExportService`, `ImpersonationService`, `PlanComparisonService`,
  `SignupService`/`SignupValidationService`, `WizardValidationService`.

Property-based testing approach (Task elsewhere; see `test/`): correctness
properties asserted with many generated inputs across the above services.

---

## 4. Performance Optimization (Task 25 — DONE)

- 25.1 DB indexes: added for tenants, licenses, audit log, plan requests (section).
- 25.2 Search debounce: 300 ms; `tenant_licensing_page.dart` `_onSearchChanged`.
- 25.3 CSV streaming: `CSVExportService.exportTenantListStreaming()` pages 200
  rows; >1000 rows serialized on a background isolate via `compute`.

---

## 5. Deployment Runbook (Tasks 26.4 / 26.5 / 26.6)

Steps apply to a Windows/macOS desktop target and/or the web build. Adjust the
PocketBase base URL via `AppBranding.defaultPocketBaseUrl` (`lib/core/constants/branding.dart`).

### 26.4 Staging
1. Run migrations (automatic on first DB open):
   `dart run build_runner build` (if schema changed) then run the app once.
2. Build + deploy web front end:
   - `flutter build web`
   - Serve the `build/web` output on your staging host; configure the PocketBase
     base URL to the staging server.
3. Smoke-test each feature in section 1 on staging accounts.

### 26.5 Regression/UAT
1. Superadmin account: onboarding wizard, licensing, audit, plan upgrades, usage
   analytics, dashboard cards, impersonate.
2. School-owner account: signup, plan upgrade request, branding, sync-failure view.
3. Verify cross-tenant isolation: owner A cannot see owner B data; impersonation
   banner and context switching behave correctly.

### 26.6 Production go-live
1. Run migrations (additive; applied on DB open).
2. Deploy web build to the production host.
3. Point the PocketBase base URL at production.
4. After go-live, watch sync engine metrics and `LicenseAlertService` alerts;
   confirm no errors in production logs.
5. Confirm the sync-failure warning is visible in the shell app bar when the
   queue has failed entries.

### Manual pre-release QA checklist (Task 26.3)
See the feature map in section 2; walk each feature once with a fresh database
and with demo data (`DEMO_TENANT_SETUP.md`).

---

## 6. Status

- Task 25 (performance): complete.
- Tasks 26.1/26.2 (docs): this document plus per-feature READMEs above.
- Tasks 26.4/26.5/26.6 (deploy): playbook provided — an actual hosting environment is required to execute.
- Tasks 24/27 (testing): intentionally out of scope per project instruction.

Roadmap implementation is feature-complete and lint-clean (`dart analyze lib` → 0 issues).