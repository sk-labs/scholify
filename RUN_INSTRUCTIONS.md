# Scholify Run Instructions

These instructions target Scholify as a desktop-first Flutter app with web support.

## Prerequisites

1. Install Flutter SDK and ensure `flutter` is available in PATH.
2. Install desktop toolchains:
     - Windows: Visual Studio with Desktop development with C++ workload
     - macOS: Xcode (if building on macOS)
3. For web support, ensure Chrome or Edge is installed.

## Setup

1. Open terminal in `scholify/`.
2. Run:

```bash
flutter pub get
```

3. Generate Drift files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Run (Desktop First)

```bash
flutter run -d windows
```

Or run web:

```bash
flutter run -d chrome
```

## Important

- This project is being migrated from Smart School source with a strict
    offline-first architecture.
- PocketBase endpoint and auth setup should be configured before module rollout.
