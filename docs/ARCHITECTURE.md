# Scholify Architecture (Current Baseline)

## Objective

Rebuild the legacy v7.2.0 baseline as Scholify with:

- Multi-tenant architecture
- Desktop-first Flutter app with web support
- Offline-first data flow
- Drift local persistence
- PocketBase remote backend
- Superadmin control plane for licensing and tenant management

## Layering

- `lib/app/`: application shell and app-level routing
- `lib/features/`: feature modules (bootstrap, superadmin, future modules)
- `lib/core/tenant/`: active tenant and role context
- `lib/core/database/`: Drift schema and local storage logic
- `lib/core/remote/`: PocketBase gateway
- `lib/core/sync/`: background sync and outbox processing

## Offline-First Flow

1. UI writes are saved to Drift immediately.
2. Writes are queued in `SyncQueueEntries` as pending operations.
3. Sync engine processes queued operations in background batches.
4. Queue entries are marked synced (or failed with retry count).
5. Pull sync uses `updated_at` checkpoints per entity.
6. Tenant scope is enforced in pull filters and local ingest for non-superadmin contexts.

## Current Tables

- `TenantRecords`: tenant identity and activation state
- `UserProfiles`: local user profile scoped to tenant
- `TenantLicenseEntries`: superadmin-issued license and plan metadata
- `SchoolOwnerEntries`: tenant owner provisioning data
- `TenantUsageMetricEntries`: synced tenant usage counters and billing metrics
- `TenantFeatureFlagEntries`: per-tenant module toggles overriding plan defaults
- `NoticeBoardEntries`: school notices and announcements with audience targeting
- `TimetableSlotEntries`: class timetable period slots per day
- `TransportRouteEntries`: transport route master with vehicle, driver, and fare details
- `HomeworkAssignmentEntries`: homework and daily assignment records
- `OnlineLearningEntries`: online course and quiz catalog items
- `LessonEntries`: lesson records per class and subject
- `LessonPlanEntries`: lesson planning records and objectives
- `SubjectEntries`: subject master records per tenant
- `SyllabusEntries`: syllabus progress and completion tracking
- `LibraryBookEntries`: library books (issued/top/general) and activity stats
- `DocumentCenterEntries`: document center items (content, videos, my-doc uploads)
- `VisitorCommunicationEntries`: visitor book, communication timeline, and comments
- `NotificationEntries`: notification center events with read/delivery states
- `LiveClassEntries`: Zoom/Gmeet live class schedule and join-link records
- `StudentDirectoryEntries`: student directory used by academic modules
- `StudentGuardianEntries`: guardian contacts mapped to students
- `StudentEnrollmentEntries`: student enrollment status per academic session
- `StudentClassRollEntries`: class-section-roll mapping per academic session
- `StudentAttendanceRecords`: attendance records (offline-first)
- `FeeInvoiceEntries`: fee invoices and payment status (offline-first)
- `FeePaymentEntries`: fee payment ledger entries (offline-first)
- `ExamScheduleEntries`: scheduled exams per tenant and month
- `StudentExamMarkEntries`: student marks linked to exam schedules
- `HomeworkSubmissionEntries`: student homework submissions with teacher review/grade state
- `OnlineLearningAttemptEntries`: student attempt records for courses and quizzes
- `SyncQueueEntries`: outbox queue for offline changes
- `SyncCheckpointEntries`: per-entity pull checkpoints

## Current Implemented Modules

1. Auth and session bootstrap (`lib/core/auth`, `lib/features/auth`)
2. Foundation shell and sync status (`lib/app`)
3. Superadmin tenant licensing (`lib/features/superadmin`)
4. School owner provisioning (`lib/features/superadmin`)
5. Superadmin usage and billing monitor (`lib/features/superadmin`)
6. Feature flags and plan-based module access control (`lib/features/superadmin`, `lib/app`)
7. Notice board announcements (`lib/features/notices`)
8. Class timetable management (`lib/features/timetable`)
9. Transport routes management (`lib/features/transport`)
10. Homework and daily assignments (`lib/features/homework`)
11. Online learning catalog (courses and quizzes) (`lib/features/online_learning`)
12. Curriculum baseline: lessons, lesson plans, subjects, and syllabus (`lib/features/curriculum`)
13. Library baseline (`lib/features/library`)
14. Document Center baseline: contents, video tutorials, my documents (`lib/features/documents`)
15. Visitor and communication baseline: visitor book, timeline, comments (`lib/features/visitor_communication`)
16. Notifications baseline: inbox/read-state management (`lib/features/notifications`)
17. Live classes baseline: Zoom + Gmeet schedules with join links (`lib/features/live_classes`)
18. Students directory (`lib/features/students`)
19. Student guardians submodule (`lib/features/students`)
20. Student enrollment status submodule (`lib/features/students`)
21. Student class roll mapping submodule (`lib/features/students`)
22. Attendance with student picker (`lib/features/attendance`)
23. Fees invoice tracking (`lib/features/fees`)
24. Exams scheduling and marks CRUD (`lib/features/exams`)
25. Exam analytics dashboard (pass-rate trends, subject performance, topper lists)
26. Homework submission and evaluation lifecycle (submit, review, grade)
27. Online learning attempt and result lifecycle (start, complete, pass/fail)

## Sync Entities (Queue + Pull)

- `tenant_license`
- `tenant_usage_metric` (pull + local monitor)
- `tenant_feature_flag` (push + pull)
- `notice_board`
- `timetable_slot`
- `transport_route`
- `homework_assignment`
- `online_learning_item`
- `lesson`
- `lesson_plan`
- `subject`
- `syllabus`
- `library_item`
- `document_center_item`
- `visitor_communication`
- `notification`
- `live_class`
- `school_owner`
- `student_profile`
- `student_guardian`
- `student_enrollment`
- `student_class_roll`
- `student_attendance`
- `fee_invoice`
- `fee_payment`
- `exam_schedule`
- `exam_mark`
- `homework_submission`
- `online_learning_attempt`

## Tenant Security Hardening

- Non-superadmin sync is scoped to active `tenant_id`.
- Pull requests include `tenant_id` filter for tenant-scoped collections.
- Sync adapter drops records with mismatched `tenant_id` when tenant scope is active.
- PocketBase rule templates are documented in `docs/POCKETBASE_TENANT_RULES.md`.
- Session restore uses persisted PocketBase auth token/model and rebuilds tenant context before shell entry.
- Superadmin navigation is role-gated in shell destinations.
- Exam sync pull now applies delete tombstones (`operation=delete` / delete flags) to local Drift state for schedule and mark records.
- Conflict policy is deterministic and timestamp-based: newer `updated_at` wins for both pull ingest and queued push dispatch (stale rows are skipped).

## Next Milestones

1. Continue module-by-module migration from the legacy baseline.

## Testing Coverage (Current)

- Widget smoke test for Scholify brand shell (`test/widget_test.dart`)
- Students + guardians + enrollment + class-roll repository tests (`test/features/students/data/student_repository_test.dart`)
- Exams repository CRUD, analytics aggregation, and sync queue tests (`test/features/exams/data/exam_repository_test.dart`)
- Exam tombstone pull-sync tests (`test/core/sync/exam_tombstone_sync_test.dart`)
- Enrollment/class-roll pull-sync tests (`test/core/sync/student_enrollment_class_roll_sync_test.dart`)
- Timestamp conflict-resolution sync tests (`test/core/sync/conflict_resolution_sync_test.dart`)
- Tenant usage metric pull-sync tests (`test/core/sync/tenant_usage_metric_sync_test.dart`)
- Tenant feature-flag push/pull and policy tests (`test/core/sync/tenant_feature_flag_sync_test.dart`, `test/core/access/module_access_policy_test.dart`)
- Notice board repository and pull-sync tests (`test/features/notices/data/notice_board_repository_test.dart`, `test/core/sync/notice_board_sync_test.dart`)
- Timetable repository and pull-sync tests (`test/features/timetable/data/timetable_repository_test.dart`, `test/core/sync/timetable_sync_test.dart`)
- Transport routes repository and pull-sync tests (`test/features/transport/data/transport_repository_test.dart`, `test/core/sync/transport_route_sync_test.dart`)
- Homework repository and pull-sync tests (`test/features/homework/data/homework_repository_test.dart`, `test/core/sync/homework_assignment_sync_test.dart`)
- Online learning repository and pull-sync tests (`test/features/online_learning/data/online_learning_repository_test.dart`, `test/core/sync/online_learning_sync_test.dart`)
- Curriculum repository and pull-sync tests (`test/features/curriculum/data/curriculum_repository_test.dart`, `test/core/sync/curriculum_sync_test.dart`)
- Library repository and pull-sync tests (`test/features/library/data/library_repository_test.dart`, `test/core/sync/library_document_sync_test.dart`)
- Document center repository tests (`test/features/documents/data/document_center_repository_test.dart`)
- Visitor communication and notification repository + pull-sync tests (`test/features/visitor_communication/data/visitor_communication_repository_test.dart`, `test/features/notifications/data/notification_repository_test.dart`, `test/core/sync/visitor_notification_sync_test.dart`)
- Live classes repository and pull-sync tests (`test/features/live_classes/data/live_class_repository_test.dart`, `test/core/sync/live_class_sync_test.dart`)
- Legacy dependency guard test to prevent new imports from legacy `lib/screens` and `lib/services/api` into `lib/app`, `lib/core`, and `lib/features` (`test/architecture/legacy_dependency_guard_test.dart`)
