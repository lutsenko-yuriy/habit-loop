# Habit Loop

[![CI](https://github.com/lutsenko-yuriy/habit-loop/actions/workflows/release.yml/badge.svg)](https://github.com/lutsenko-yuriy/habit-loop/actions/workflows/release.yml)
[![Coverage](https://codecov.io/gh/lutsenko-yuriy/habit-loop/graph/badge.svg)](https://codecov.io/gh/lutsenko-yuriy/habit-loop)
[![Scenarios](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lutsenko-yuriy/ca542be92a8f3e51c0097ef336579207/raw/scenarios.json)](https://github.com/lutsenko-yuriy/habit-loop/actions/workflows/release.yml?query=branch%3Amain)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Flutsenko-yuriy%2Fhabit-loop%2Fmain%2Fpubspec.yaml&query=%24.version&label=version&color=blue)](https://github.com/lutsenko-yuriy/habit-loop/blob/main/docs/CHANGELOG.md)

Build habits through pacts and showups.

Habit Loop lets you make a **pact** with yourself: commit to showing up for a habit for a fixed period. Each scheduled session is a **showup**. At the end, you know exactly how you did — no excuses, no pauses.

## Running it

**Requires:** the Flutter SDK (stable channel), Xcode and CocoaPods for iOS, and the
Android SDK with JDK 17 for Android.

Three Firebase config files are not committed and must be obtained separately:

| File | How to obtain |
|---|---|
| `lib/firebase_options.dart` | `flutterfire configure` |
| `android/app/google-services.json` | Firebase Console → Android app |
| `ios/Runner/GoogleService-Info.plist` | Firebase Console → iOS app |

```bash
flutter pub get
flutter gen-l10n          # again after editing any lib/l10n/*.arb file
flutter run -d ios        # or -d android
```

Available in English, French, German and Russian. Android builds ship through Firebase
App Distribution, iOS builds through TestFlight. See `docs/PRODUCT_SPEC.md` for the
features and behaviour.

## Testing

```bash
flutter test                                                   # unit and widget tests
flutter analyze
dart format -l 120 lib/ test/ integration_test/
flutter test integration_test/ -d <device-id>                  # scenarios, needs a running device
python3 -m unittest discover -s scripts -p 'test_*.py' -t scripts  # agent and release tooling
```

Run the Python tests on 3.11+. `docs/CI_PIPELINE.md` covers the CI jobs,
distribution and required secrets.

## Architecture

Vertical-slice architecture with Riverpod (state and DI) and sqflite (local storage):

- `lib/slices/`: one slice per feature, with `application`, `data`, `ui` and `analytics` layers as needed.
- UI is platform-split: `ios/` (Cupertino) and `android/` (Material), plus `generic/` for shared view models and widgets.
- `lib/domain/`: domain models and repository interfaces shared across slices.
- `lib/infrastructure/`: analytics, auth, crash reporting, notifications, sync and DI wiring.

Providers are declared in `lib/infrastructure/injections/app_providers.dart`. See
`docs/ARCHITECTURE.md` for the full layout and `docs/TECH_STACK.md` for languages and tooling.

## Working on this project with Claude Code

This repo uses the
[agentic-boyz](https://github.com/lutsenko-yuriy/yuriys-agentic-boyz)
multi-skill workflow. `AGENTS.md`, included via `CLAUDE.md`, is the
orchestrator. It points to the skills under `skills/` and to the project facts in `docs/`.
Issues and backlog live in [GitHub Issues](https://github.com/lutsenko-yuriy/habit-loop/issues) (prefix `HAB`: HAB-N is issue #N; HAB-1..281 are an older, read-only Linear archive).

**Requires:** `git`, `python3`, a Python 3.11+ interpreter and an authenticated `gh` (`gh auth login`).
The gate runs on any `python3`, 3.9 included. Without `python3`, the gate denies every tool call, and `/onboard` can't fix that.
Onboarding's `check`, `apply` and `mark` need 3.11+ (for example `python3.12`). `/onboard` looks for one and asks you to install it if none is found.

1. Open Claude Code **from the repo root**. Claude Code reads `.claude/settings.json` only
   from the directory it starts in. If you start it from a subdirectory, the gate hooks
   don't load.
2. Run `/onboard`. Until it finishes, a gate blocks most writes, other skills, subagents
   and shell commands. The project is already configured, so here it gives a short
   orientation and then writes a per-clone marker inside the git dir. The marker is never
   committed, so each collaborator runs `/onboard` once.
3. Start with `/summarize`.

Machine-specific settings (Flutter binary path, API keys) go in a gitignored `CLAUDE.local.md`.

If you change the configuration, commit and push it, so collaborators don't work from a stale one.

## Licence

MIT. See [LICENSE](LICENSE).
