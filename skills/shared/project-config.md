# Project Config

Read this file to resolve all project-specific constants referenced in skill instructions. When porting this skill set to a new project, update only this file — skill logic stays unchanged.

## Source control

| Setting | Value |
|---|---|
| Git host | GitHub |

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State management | Riverpod |
| Local persistence | sqflite |
| Remote config / distribution | Firebase |

## Project management

@skills/shared/pm-tool-mapping.md

## Documentation paths

| Document | Path |
|---|---|
| Product spec | `docs/PRODUCT_SPEC.md` |
| Glossary | `docs/GLOSSARY.md` |
| Backlog | `docs/BACKLOG.md` |
| Changelog | `docs/CHANGELOG.md` |
| Architecture | `docs/ARCHITECTURE.md` |
| Analytics events | `docs/ANALYTICS_EVENTS.md` |
| Feature toggles | `docs/FEATURE_TOGGLES.md` |
| Feature workflow | `docs/FEATURE_WORKFLOW.md` |
| Troubleshoot workflow | `docs/TROUBLESHOOT_WORKFLOW.md` |
| Knowledge base | `docs/knowledge/notes/` (one `HAB-XX.md` file per ticket) |
| Decisions (ADRs) | `docs/decisions/` (one `ADR-NNN-<short-name>.md` file per standing decision) |

## Testing

| Setting | Value |
|---|---|
| Integration test directory | `integration_test/` |
| Test harness file | `integration_test/harness.dart` |
| Harness usage | Use `AppHarness` for all scenario setup and driver calls |
| Unit/integration test command | `flutter test` |

## Version management

| Setting | Value |
|---|---|
| Version file | `pubspec.yaml` |
| Version field | `version: X.Y.Z+buildNumber` |
| Manual vs automated | Bump `X.Y.Z` manually; CI manages `+buildNumber` — never touch it |

## In QA path patterns

A merged PR moves to **In QA** (not Done directly) if it touches any of:

- `lib/slices/*/ui/` — any widget or screen change
- `lib/infrastructure/persistence/` — schema or mapper changes
- `lib/infrastructure/sync/` — external sync behaviour
- `lib/infrastructure/notifications/` — notification scheduling
- `main.dart` — app wiring or startup sequence
- `integration_test/` — always In QA when integration tests are added or changed

Move straight to **Done** if the PR touches only: pure domain/application logic, documentation, CI config, l10n strings without new screens, or pure refactors where automated tests fully own correctness. When in doubt, use **In QA**.
