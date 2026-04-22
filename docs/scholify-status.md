- Auth/session bootstrap implemented: persisted PocketBase token/model restore, sign-in gate, and role-aware shell entry.
- Tenant scope hardening active in sync engine, adapter, and gateway pull filters.
- Fees module baseline added: local FeeInvoiceEntries table, fee_invoice queue entity, checkpointed pull sync, and desktop Fees page.
- Before git init, run final Smart School reference cleanup for Scholify-owned files only.
- Fees workflow enhanced: status filter chips (all/due/partial/paid), mark-as-paid action, and editable payment amount per invoice.


- Exams baseline added: local schedule/marks tables, exam_schedule + exam_mark sync entities, new Exams shell tab, and offline-first exam/mark entry UI.

- Drift codegen runs cleanly with `dart run build_runner build --delete-conflicting-outputs`; `flutter pub run` now prints deprecation notice.

- Exams module hardened to CRUD: schedule edit/delete with cascading mark removal, mark edit/delete, remote delete dispatch support, and repository tests under test/features/exams/data.

- Sync adapter now handles exam pull tombstones (delete ops/flags) by deleting local schedule/mark records; covered by test/core/sync/exam_tombstone_sync_test.dart.

- Students guardians submodule implemented: StudentGuardianEntries table (schema v11), guardian sync entity, new Guardians shell tab/page, and repository tests in test/features/students/data/student_repository_test.dart.

- Students enrollment + class-roll submodules implemented: new Drift tables (schema v13), queue entities (`student_enrollment`, `student_class_roll`), PocketBase gateway + sync adapter push/pull wiring, shell tabs/pages, and repository test coverage updates.
- Validation completed for this milestone: `dart run build_runner build --delete-conflicting-outputs`, targeted students/sync tests, and full `flutter test` suite passing (89 tests).

- Exam analytics dashboard milestone completed: repository analytics stream (pass-rate, subject performance, topper rankings, grade distribution, daily trend), new analytics panel in Exams UI, and database analytics mark-row query.
- Analytics validation completed with codegen and full tests passing after integration.

- Deterministic sync conflict resolution implemented with timestamp policy: newer `updated_at` wins for pull ingest and pending queue dispatch (stale queue operations auto-skipped).
- Added sync regression coverage for conflict policy under test/core/sync/conflict_resolution_sync_test.dart.
- Per-tenant usage and billing monitor implemented: new `TenantUsageMetricEntries` table (schema v14), sync pull/checkpoint for `tenant_usage_metric`, Superadmin monitor page, and dashboard navigation.
- Added usage metric sync regression test in test/core/sync/tenant_usage_metric_sync_test.dart and validated with full test suite passing (95 tests).
- Feature flags + plan-based module access control implemented: new `TenantFeatureFlagEntries` table (schema v15), `tenant_feature_flag` sync entity (push/pull), shell-level module gating from plan defaults + tenant overrides, and Superadmin feature-flag management page.
- Added regression/unit coverage: test/core/sync/tenant_feature_flag_sync_test.dart and test/core/access/module_access_policy_test.dart; validated with full suite passing (99 tests).



- Timetable module baseline implemented: new `TimetableSlotEntries` Drift table (schema v17), `timetable_slot` sync entity (push/pull with checkpoint + tombstone handling), shell module tab, and feature-flag policy integration.
- Added timetable coverage: `test/features/timetable/data/timetable_repository_test.dart` and `test/core/sync/timetable_sync_test.dart`; validated with full suite passing (103 tests).

- Transport routes milestone implemented: new `TransportRouteEntries` table wiring (schema v18), `transport_route` gateway + sync adapter support (push/pull/checkpoint/tombstones), shell module tab, and feature-flag policy integration.
- Added transport coverage: `test/features/transport/data/transport_repository_test.dart` and `test/core/sync/transport_route_sync_test.dart`; full suite now passing (105 tests).

- Homework + daily assignments milestone implemented: new `HomeworkAssignmentEntries` table (schema v19), `homework_assignment` gateway + sync adapter support (push/pull/checkpoint/tombstones), shell module tab, and feature-flag policy integration.
- Added homework coverage: `test/features/homework/data/homework_repository_test.dart` and `test/core/sync/homework_assignment_sync_test.dart`; full suite now passing (107 tests).

- Online learning baseline implemented: new `OnlineLearningEntries` table (schema v20), `online_learning_item` gateway + sync adapter support (push/pull/checkpoint/tombstones), shell module tab, and feature-flag policy integration.
- Added online learning coverage: `test/features/online_learning/data/online_learning_repository_test.dart` and `test/core/sync/online_learning_sync_test.dart`; full suite now passing (109 tests).


- Curriculum baseline implemented: added `LessonEntries`, `LessonPlanEntries`, `SubjectEntries`, and `SyllabusEntries` (schema v21), with queue entities (`lesson`, `lesson_plan`, `subject`, `syllabus`), PocketBase gateway + sync adapter push/pull/checkpoint/tombstones, and shell curriculum module tab.
- Added curriculum coverage: `test/features/curriculum/data/curriculum_repository_test.dart` and `test/core/sync/curriculum_sync_test.dart`; full suite now passing (111 tests).

- Library + Document Center migration baseline implemented: new local tables (`LibraryBookEntries`, `DocumentCenterEntries`) in schema v22, queue entities (`library_item`, `document_center_item`), gateway push/pull, sync adapter checkpoints/tombstone handling, and shell module tabs.
- Added module coverage for library/documents and sync: `test/features/library/data/library_repository_test.dart`, `test/features/documents/data/document_center_repository_test.dart`, and `test/core/sync/library_document_sync_test.dart`.
- Curriculum workflows enriched: lesson attachment upload queueing, syllabus progress analytics stream, and lesson plan template presets in curriculum repository/page.
- Legacy dependency elimination pass started: added `test/architecture/legacy_dependency_guard_test.dart` to block imports from legacy `lib/screens` and `lib/services/api` into modern `lib/app`, `lib/core`, and `lib/features`.
- Validation complete after this milestone: targeted regression tests and full `flutter test` equivalent run via tooling now passing (116 tests).

- Visitor/communication + notifications baseline implemented: new local tables (`VisitorCommunicationEntries`, `NotificationEntries`) in schema v23, queue entities (`visitor_communication`, `notification`), gateway push/pull, sync adapter checkpoints/tombstones, shell tabs, and feature-flag policy integration.
- Added coverage for this block: `test/features/visitor_communication/data/visitor_communication_repository_test.dart`, `test/features/notifications/data/notification_repository_test.dart`, and `test/core/sync/visitor_notification_sync_test.dart`.
- Validation complete after this milestone: codegen + full test suite passing (119 tests).

- Live classes baseline implemented: new `LiveClassEntries` table (schema v24), `live_class` sync entity (gateway + adapter push/pull/checkpoint/tombstones), shell module tab, and feature-flag policy integration.
- Added live-class coverage: `test/features/live_classes/data/live_class_repository_test.dart` and `test/core/sync/live_class_sync_test.dart`, plus sync fake gateway overrides for `pullLiveClasses` across core sync tests.
- Validation complete after this milestone: codegen + full test suite passing (121 tests).
- Hostel / leave / pending-task migration completed: new offline-first feature modules, PocketBase push/pull support, sync checkpoints/tombstones, shell access flags, and regressions for repositories + sync + access policy.
- Legacy pending-task/calendar todo screens now act as compatibility wrappers over the modern pending-tasks module via shared app runtime state.
- Validation complete after this milestone: `dart run build_runner build --delete-conflicting-outputs` and targeted module tests passing.

- Legacy leave and hostel screens now also delegate to the modern offline-first modules via shared app runtime state.
- LeaveRequestsPage now accepts optional legacy leave data so edit flows remain functional through the modern module.

- Course payments migrated into a modern feature module with legacy screen wrappers for payment launch, webview, and success pages.

- Student behaviour module implemented: new `StudentBehaviourEntries` + `BehaviourCommentEntries` tables (schema v31), `student_behaviour` + `behaviour_comment` sync entities (push/pull/checkpoint/tombstones), `StudentBehaviourRepository` with comment add/delete, and `StudentBehaviourPage` with incident list and inline comments bottom sheet.
- Teacher directory + reviews module implemented: new `TeacherEntries` table (schema v32) with rating/review state, `teacher` sync entity (push/pull/checkpoint/tombstones), `TeacherRepository` with `submitReview`, and `TeachersPage` with teacher cards, contact details, class-teacher badge, and star-rating dialog.
- Online lesson content module implemented: new `OnlineLessonEntries` table (schema v33), `online_lesson` sync entity (push/pull/checkpoint/tombstones), `OnlineLessonRepository` with save/markCompleted/delete, and `CourseDetailPage` showing course info, lesson list with content-type icons, completion tracking, and URL launch.
- Shell wired: `TeachersPage` and `StudentBehaviourPage` added as feature-gated destinations; `teachers` and `student_behaviour` module keys added to `ScholifyModuleFeature` and all three plan defaults.
- Added regression coverage: `test/core/sync/behaviour_teachers_lessons_sync_test.dart` (4 tests covering pull ingest, tombstones, cross-tenant filtering, checkpoints for all four new entities); all 18 existing sync test fake gateways updated.
- Validation complete: codegen clean and full test suite passing (55 tests).
- CBSE exam results module implemented: new `CbseExamResultEntries` table (schema v29), `cbse_exam_result` sync entity (push/pull/checkpoint/tombstones), `CbseExamRepository`, and `CbseExamPage` with subject-wise marks table, assessment columns, grade/rank/percentage summary, and schedule view.
- Online exam catalog module implemented: new `OnlineExamEntries` table (schema v30), `online_exam` sync entity (push/pull/checkpoint/tombstones), `OnlineExamRepository` with submit/score tracking, and `OnlineExamPage` with upcoming/closed tabs and score submission dialog.
- Added regression coverage: `test/core/sync/enterprise_fees_cbse_online_exam_sync_test.dart` covering all three new entities (pull ingest, tombstones, cross-tenant filtering, checkpoints); all 17 existing sync test fake gateways updated with new pull method overrides.
- Validation complete after this milestone: codegen clean and full test suite passing (51 tests).
- Online learning attempt/result lifecycle implemented: new `OnlineLearningAttemptEntries` table (schema v27), `online_learning_attempt` sync entity (gateway + adapter push/pull/checkpoint/tombstones), start/complete/delete repository methods, and inline attempts panel in Online Learning UI.
- Auth legacy dependency elimination completed: `change_password_page.dart`, `forgot_password_page.dart`, and `profile_page.dart` in `lib/features/auth/presentation` now use PocketBase directly via `AppRuntime` — legacy `ProfileApi` and `AuthApi` imports removed.
- Added regression coverage: `test/features/homework/data/homework_submission_test.dart`, `test/features/online_learning/data/online_learning_attempt_test.dart`, `test/core/sync/homework_submission_sync_test.dart`, and `test/core/sync/online_learning_attempt_sync_test.dart`; all 15 existing sync test fake gateways updated with new pull method overrides.
- Validation complete after this milestone: `dart run build_runner build --delete-conflicting-outputs` and full test suite passing (48 tests).

- Legacy dependency elimination completed: removed `lib/screens`, `lib/models`, `lib/providers`, `lib/services`, `lib/utils`, `lib/widgets`, and `lib/config` — `lib/` now contains only `app/`, `core/`, `features/`, `bootstrap.dart`, and `main.dart`. Guard test green, full suite passing (55 tests).
