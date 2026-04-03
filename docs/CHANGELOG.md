# Changelog

## Unreleased

### Proposed product changes

- We should probably warn a user if there are already too many pacts he created.
    - Research: how many pacts can a user follow physically?
    - Even before creating a pact (as a step 0, if you want to) that there are already too many pacts (show the exact number).
    - Let the user proceed with the creation only if he is sure he wants to create more pacts.
    - On dashboard in the calendar strip reorganize the dots under the dates so that on a single line there are no more than 2 dots:
       - One dot if there is a single showup on the date.
       - Two dots if there are two showups on the date.
       - Two dots on first line and one dot on second line if there are three showups on the date.
       - Two dots on first line and two dots on second line if there are four showups on the date.
       - One giant dot if there are more than four showups on the date.

### Issues

- [#6](https://github.com/lutsenko-yuriy/habit-loop/issues/6) **Refactor: reduce duplicated logic between iOS and Android dashboard widgets** — `_buildDots()` (status counting, layout, overflow colour) and the showup list/tile are duplicated verbatim across both platform pages. Extract shared logic into platform-agnostic helpers once there are enough instances to justify the abstraction.
- **Tech debt — rollback exception masks original error** (`pact_creation_view_model.dart`): if `saveShowups` fails and the compensating `deletePact` call also throws (e.g. DB locked), the rollback exception replaces the original showup error and the pact remains orphaned. **Proposed solution:** have the SQLite implementation class implement both `PactRepository` and `ShowupRepository`, giving it a single `Database` reference. It can then expose a transactional method (e.g. `savePactWithShowups(pact, showups)`) that wraps both inserts in one `db.transaction()`, eliminating the need for manual rollback in the view model. Note: simply sharing the class isn't enough — the existing `savePact()` and `saveShowups()` are separate async calls with separate implicit transactions, so a dedicated combined method is required for atomicity.
- [#2](https://github.com/lutsenko-yuriy/habit-loop/issues/2) **Refactor: replace `PactCreationState` with a `PactBuilder`** — `PactCreationState` mixes wizard navigation state with pact-building data. Extract a `PactBuilder` class that holds only the pact fields and exposes a `build()` method returning a `Pact`.

### Remaining work

- **SQLite persistence** — replace in-memory `PactRepository` and `ShowupRepository` with real `sqflite` implementations
- **Pact detail screen** — stats (showups made / failed / remaining), time details (start date, end date, days remaining), current streak, stop pact with confirmation dialog and optional explanation; accessible for stopped and expired pacts
- **Pact list** — navigate from dashboard to a list of all active and past pacts
- **Showup detail screen** — view showup time and habit name, mark as done or failed, auto-fail if the screen is opened after the scheduled showup time, leave a free-text note
- **Notifications / reminders** — schedule local notifications when a reminder offset is configured during pact creation; stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app

---

## [0.2.0] — 2026-04-03 (PR #4 merged)

### Added — Dashboard wiring

- Showups are now generated and persisted when a pact is created via `PactCreationViewModel.submit()`
- `pactCreationShowupRepositoryProvider` — new Riverpod provider for the showup repository used during pact creation
- `deletePact(String id)` added to `PactRepository` interface and `InMemoryPactRepository`
- Shared `InMemoryShowupRepository` instance wired between dashboard and pact creation in `main.dart`
- Integration test: submit pact → load dashboard → assert showups appear in `calendarDays`

### Fixed

- `endDate` overflow: replaced `DateTime(today.year, today.month + 6, today.day)` with month-overflow-safe `_addMonths()` that clamps the day to the last day of the target month
- iOS `CupertinoDatePicker` assertion: `initial date not >= minimumDate` — strip time component from today when used as `minimumDate`
- iOS modal pickers: Done button no longer cut off by home indicator — switched to `mainAxisSize: MainAxisSize.min` + `SizedBox(height: viewPadding.bottom)` instead of a fixed calculated container height; applied to all pickers in pact duration and schedule steps
- Orphaned pact rollback: `saveShowups` failure now triggers `deletePact` to clean up; failure is surfaced via `submitError`; masking risk documented as tech debt

### Tests

- `pact_creation_view_model_test.dart`: added showup repo override to all containers, 3 new tests (generates showups, skips showups on pact failure, sets error on showup failure)
- `pact_creation_state_test.dart`: end-of-month edge cases for `_addMonths`

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
