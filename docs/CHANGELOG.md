# Changelog

## Unreleased

### Issues

- **Tech debt — rollback exception masks original error** (`pact_creation_view_model.dart`): if `saveShowups` fails and the compensating `deletePact` call also throws (e.g. DB locked), the rollback exception replaces the original showup error and the pact remains orphaned. Proper fix: wrap both writes in a single `db.transaction()` once the SQLite implementation is in place, eliminating the need for manual rollback entirely.

### Remaining work

- **SQLite persistence** — replace in-memory `PactRepository` and `ShowupRepository` with real `sqflite` implementations
- **Pact detail screen** — stats (showups made / failed / remaining), time details (start date, end date, days remaining), current streak, stop pact with confirmation dialog and optional explanation; accessible for stopped and expired pacts
- **Pact list** — navigate from dashboard to a list of all active and past pacts
- **Showup detail screen** — view showup time and habit name, mark as done or failed, auto-fail if the screen is opened after the scheduled showup time, leave a free-text note
- **Dashboard wiring** — connect the calendar strip and today's showup list to real persisted data instead of the current empty state
- **Notifications / reminders** — schedule local notifications when a reminder offset is configured during pact creation; stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app

---

## [0.1.0] — 2026-03-?? (PR #3 merged)

### Added — Showup domain layer

- `Showup` model with `id`, `pactId`, `scheduledAt`, `duration`, `status`, and optional `note`
- `ShowupStatus` enum: `pending`, `done`, `failed`
- `ShowupGenerator` — deterministically generates all `Showup` instances for a pact from its `ShowupSchedule`
- `ShowupRepository` interface and `InMemoryShowupRepository` implementation
- `ShowupDateUtils` — helpers for date arithmetic used during generation
- `SaveShowupsResult` — result type returned when persisting a batch of showups
- `PactStats` — computed stats for a pact: made, failed, remaining, and current streak
- Showups are generated and persisted automatically when a pact is created via `PactCreationViewModel`

---

## [0.0.2] — 2026-02-?? (PR #1 merged)

### Added — Pact creation wizard

- 5-step wizard: commitment confirmation → habit name → pact duration → showup duration → schedule → reminder
- `ShowupSchedule` supporting three modes: every day at a time, specific weekdays, specific days of the month
- `PactCreationState` and `PactCreationViewModel` (Riverpod notifier) managing wizard state
- `PactRepository` interface and `InMemoryPactRepository` implementation
- `Pact` model and `PactStatus` enum (`active`, `stopped`, `completed`)
- Platform-split UI: separate iOS (`CupertinoPageScaffold`) and Android (`Scaffold`) widgets for each step
- Fix: schedule step no longer loses entered entries when navigating back

### Added — Dashboard

- Dashboard screen with a 7-day calendar strip (3 days before / today / 3 days after)
- Today's showup list placeholder (empty state)
- Platform-split UI: `DashboardPageIos` and `DashboardPageAndroid`
- `DashboardState` and `DashboardViewModel`

---

## [0.0.1] — 2026-01-?? (initial scaffold)

### Added

- Flutter project scaffold targeting iOS and Android
- Riverpod for state management and dependency injection
- sqflite dependency for local storage (not yet used)
- Localizations in English, French, and German (`flutter gen-l10n`, output to `lib/l10n/generated/`)
- `analysis_options.yaml` with `package:flutter_lints`
- CI/CD pipeline (GitHub Actions): test → resolve-version → build-android / build-ios → distribute → version tag
