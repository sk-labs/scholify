# Legacy Dependency Elimination Plan

## Goal

Remove runtime dependencies on legacy Smart School surfaces under lib/screens and lib/services/api while preserving feature parity in Scholify modules.

## Current State

- App shell and modern modules in lib/app, lib/core, and lib/features now have a guard test preventing direct imports from legacy screens/api folders.
- Remaining legacy code still exists in workspace and can be removed only after migrated module parity and regression checks are complete.

## Enforced Guard

- Test: test/architecture/legacy_dependency_guard_test.dart
- Rule: no imports from /screens/ or /services/api/ in:
  - lib/app
  - lib/core
  - lib/features

## Elimination Steps

1. Continue migrating remaining legacy modules into lib/features with Drift + sync patterns.
2. Keep guard test green while replacing legacy entry points with feature modules.
3. Add regression tests for each migrated capability.
4. Remove unreferenced legacy files in stages.
5. Re-run full tests and acceptance checks before final archive/delete.
