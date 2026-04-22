# Smart School -> Scholify Parity Matrix

Status legend:
- DONE: Migrated into Scholify feature modules with sync/tests
- PARTIAL: Some capability migrated, not full legacy parity
- TODO: Not yet migrated to Scholify baseline modules
- DROP_CANDIDATE: Candidate to remove after dependency checks

## Core Platform

| Area | Legacy Surface | Scholify Status | Notes |
|---|---|---|---|
| Auth/session | login, forgot password, profile/session flows | DONE | Modern auth/session bootstrap complete; profile, forgot-password, and change-password pages use PocketBase directly; legacy login path still exists as wrapper |
| Superadmin control plane | licensing, owner provisioning, billing/usage, access flags | DONE | Migrated with offline-first sync and feature-gated shell |
| Tenant-aware sync | multi-entity pull/push + checkpoints + conflicts | DONE | Timestamp conflict policy + tenant scoping in place |

## Academic Modules

| Area | Legacy Surface | Scholify Status | Notes |
|---|---|---|---|
| Students directory | student lists/details | DONE | Includes guardians, enrollment, class-roll |
| Attendance | attendance records | DONE | Baseline attendance flow present |
| Exams | schedules, marks, analytics, results variants | DONE | Core exam workflows, analytics, CBSE results/schedule, and online exam catalog all migrated |
| Timetable | timetable page | DONE | Baseline class timetable migrated |
| Homework | homework + daily assignment flows | DONE | Baseline CRUD/sync done; submission/evaluation lifecycle implemented |
| Transport | transport routes page | DONE | Baseline routes module migrated |
| Online course + quiz | online course pages + quiz attempts/results | DONE | Catalog + attempt/result lifecycle + course detail + lesson content all migrated |
| Lesson + lesson plan | lesson pages | DONE | Baseline lesson and lesson-plan CRUD/sync migrated |
| Syllabus + subjects | syllabus status/detail + subjects | DONE | Baseline syllabus and subject CRUD/sync migrated |
| Library | library page | DONE | Offline-first baseline with local CRUD, sync queue, and pull/checkpoint |

## Operations and Communication

| Area | Legacy Surface | Scholify Status | Notes |
|---|---|---|---|
| Notice board | notices | DONE | Migrated |
| Download/document center | my docs, download center, uploads | DONE | Baseline document center module with download/video/my-document flows and sync |
| Visitor/communication | visitors, visitor book, timeline, comments | DONE | Baseline visitor book + timeline + comments module with offline-first sync |
| Notifications | notification pages/debug | DONE | Notification center baseline with read-state, queue sync, and pull checkpoints |
| Live classes | zoom/gmeet pages | DONE | Baseline Zoom/Gmeet live classes module with offline-first sync and join links |
| Hostel/leave/tasks | hostel, leave, pending tasks, calendar todo | DONE | All migrated; legacy calendar todo delegates to modern pending tasks module |
| Student behaviour | student behaviour + comments | DONE | Incident records with comment threads, offline-first sync, and shell tab |
| Teacher directory + reviews | teachers list + star ratings | DONE | Teacher directory with contact info, class-teacher badge, and review submission |

## Finance and Commerce

| Area | Legacy Surface | Scholify Status | Notes |
|---|---|---|---|
| Fees + payments | fees, offline payment, enterprise fees | DONE | Core invoices/payments + enterprise fee groups (categories, discount, fine, processing, offline bank payments) migrated |
| Course payments | course payment pages/webview/success | DONE | Modern course-payment module added with wrapper screens for legacy launch points |

## Production Readiness Gates

| Gate | Status | Notes |
|---|---|---|
| Feature parity matrix tracked | DONE | This file is the source of truth |
| Core sync and conflict coverage | DONE | Entity pull/push + tombstone tests in place for migrated modules |
| End-to-end regression suite (critical user journeys) | TODO | Needed before legacy cleanup |
| Release hardening (telemetry, audit, rollout controls) | TODO | Required for production readiness |
| Legacy dependency elimination in scholify/lib/screens and scholify/lib/services/api | DONE | All legacy directories removed: lib/screens, lib/models, lib/providers, lib/services, lib/utils, lib/widgets, lib/config — only lib/app, lib/core, lib/features remain |

## Cleanup Sequencing

1. Finish TODO/PARTIAL migrations module by module.
2. Remove active imports from legacy-style paths in Scholify workspace.
3. Run full regression and acceptance checks.
4. Archive or delete Smart School folders only after zero active dependency.
