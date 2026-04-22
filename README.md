# Scholify

Scholify is a desktop-first, multi-tenant school platform built with Flutter, backed by PocketBase and Drift for offline-first sync.

## Architecture

- `lib/app/` — app shell, routing, and runtime state
- `lib/core/` — database schema (Drift), PocketBase gateway, sync engine, tenant context, access policy
- `lib/features/` — all feature modules (offline-first, each with data + presentation layers)

## Key Characteristics

- **Offline-first** — all writes go to Drift immediately, queued for background sync
- **Multi-tenant** — all data scoped by `tenant_id`; sync pull filters enforce tenant isolation
- **Feature-gated** — module access controlled by plan code + per-tenant feature flag overrides
- **Desktop-first** — NavigationRail layout for wide screens, NavigationBar for narrow

## Running

```bash
dart run build_runner build --delete-conflicting-outputs  # regenerate Drift code
flutter test                                               # run test suite (55 tests)
flutter run -d windows                                     # run on Windows desktop
```

## Docs

- `docs/ARCHITECTURE.md` — layering, offline-first flow, sync entities
- `docs/PARITY_MATRIX.md` — feature migration status (all modules DONE)
- `docs/POCKETBASE_TENANT_RULES.md` — PocketBase collection rule templates
- `docs/scholify-status.md` — milestone-by-milestone build log
