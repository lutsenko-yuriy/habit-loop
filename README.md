# Habit Loop

[![CI](https://github.com/lutsenko-yuriy/habit-loop/actions/workflows/ci.yml/badge.svg)](https://github.com/lutsenko-yuriy/habit-loop/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/lutsenko-yuriy/habit-loop/graph/badge.svg)](https://codecov.io/gh/lutsenko-yuriy/habit-loop)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Flutsenko-yuriy%2Fhabit-loop%2Fmain%2Fpubspec.yaml&query=%24.version&label=version&color=blue)](https://github.com/lutsenko-yuriy/habit-loop/blob/main/docs/CHANGELOG.md)

Build habits through pacts and showups.

Habit Loop lets you make a **pact** with yourself: commit to showing up for a habit for a fixed period. Each scheduled session is a **showup**. At the end, you know exactly how you did — no excuses, no pauses.

---

## Platforms

| Platform | Status |
|---|---|
| iOS | Distributed via Firebase App Distribution |
| Android | Distributed via Firebase App Distribution |

## Supported languages

English · French · German · Russian

---

## Tech stack

| Layer | Technology |
|---|---|
| UI framework | Flutter (Dart SDK ^3.6.0) |
| State management / DI | Riverpod |
| Local storage | sqflite |
| Auth | Firebase Auth (anonymous + Google sign-in) |
| Analytics | Firebase Analytics |
| Crash reporting | Firebase Crashlytics |
| Feature flags | Firebase Remote Config |
| Sync | Cloud Firestore |
| Notifications | flutter_local_notifications |

---

## Getting started

### Prerequisites

- Flutter SDK (stable channel). Full binary path stored in `CLAUDE.local.md` (not on default `PATH` on all machines)
- Xcode (iOS builds)
- Android Studio or the Android SDK (Android builds)
- CocoaPods (`gem install cocoapods`)

### Credential files (not committed)

Three files are excluded from version control and must be sourced separately:

| File | How to obtain |
|---|---|
| `lib/firebase_options.dart` | `flutterfire configure` |
| `android/app/google-services.json` | Firebase Console → Android app |
| `ios/Runner/GoogleService-Info.plist` | Firebase Console → iOS app |

### First-time setup

```bash
flutter pub get
flutter gen-l10n
```

---

## Common commands

```bash
# Run on a connected device or simulator
flutter run

# Run on a specific platform
flutter run -d ios
flutter run -d android

# Run all unit tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Static analysis
flutter analyze

# Re-generate localizations (required after editing any lib/l10n/*.arb file)
flutter gen-l10n

# Format code
dart format -l 120 lib/ test/
```

> **Note:** `flutter` may not be on your `PATH`. Use the full binary path from your local `CLAUDE.local.md` if needed.

---

## Architecture

Vertical-slice architecture: each product feature lives in its own slice under `lib/slices/` with four layers — **domain**, **application**, **data**, and **UI**.

Cross-cutting infrastructure (analytics, auth, crash reporting, notifications, sync) lives under `lib/infrastructure/`. Pure domain models and repository interfaces shared across features live under `lib/domain/`.

UI is **platform-split**: each slice has `ios/` (Cupertino) and `android/` (Material) subdirectories alongside a `generic/` directory for shared view models, formatters, and widgets.

State management uses **Riverpod**. All providers are declared in `lib/infrastructure/injections/app_providers.dart`; production wiring happens in `lib/infrastructure/injections/app_container.dart`.

For full details see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Documentation

| File | Contents |
|---|---|
| [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) | Feature requirements |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Code organisation, layers, directory structure |
| [`docs/GLOSSARY.md`](docs/GLOSSARY.md) | Ubiquitous language — canonical domain terms and known aliases |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | Released version history |
| [`docs/BACKLOG.md`](docs/BACKLOG.md) | Known issues and planned work |
| [`docs/VERSIONING.md`](docs/VERSIONING.md) | Version numbering and CI/CD pipeline |
| [`docs/ANALYTICS_EVENTS.md`](docs/ANALYTICS_EVENTS.md) | Analytics event catalogue |

---

## CI/CD

GitHub Actions pipeline on every push to `main`:

```
test → resolve-version → build-android → distribute-android ─┐
                        → build-ios     → distribute-ios     ──┤
                                                               └→ version-tag
```

- **Test job**: lint, format check, unit tests (integration tests run locally as the pre-merge gate)
- **Build jobs**: signed AAB (Android) and IPA (iOS)
- **Distribute jobs**: upload to Firebase App Distribution
- **Version tag**: bumps the build number in `pubspec.yaml` and creates a `version-X.Y.Z-N-{platform}` git tag

Feature branch builds run the test job only (no distribution, no tagging).

Required secrets are documented in [`docs/VERSIONING.md`](docs/VERSIONING.md).

---

## Licence

MIT — see [LICENSE](LICENSE)
