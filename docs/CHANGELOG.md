# Changelog

A record of all versioned releases. For planned work and known issues, see @docs/BACKLOG.md.

---

## [0.9.3] — 2026-04-10 (PR #17 merged)

### Added — Firebase project setup (HAB-27)

- `firebase_core` added to `pubspec.yaml`; `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` called in `main.dart` before `runApp`, so all subsequent Firebase SDKs (Analytics, Remote Config, App Distribution) can be added without further wiring
- `com.google.gms:google-services` Gradle plugin applied to `android/settings.gradle.kts` and `android/app/build.gradle.kts`
- `ios/Runner.xcodeproj/project.pbxproj` updated with Firebase configuration entries
- `lib/firebase_options.dart` added to `.gitignore` alongside `google-services.json` and `GoogleService-Info.plist` — credentials are never committed; branch history cleaned with `git filter-repo` to remove accidentally committed secrets

---

## [0.9.2] — 2026-04-10 (PR #16 merged)

### Changed — Showup generation window and date arithmetic

- Replaced `DateTime(year, month, day + 7)` arithmetic in `pact_creation_view_model.dart` and `dashboard_view_model.dart` with `date.add(const Duration(days: 7))`, which handles month-end boundaries correctly and is consistent with the `_addMonths()` pattern introduced in v0.2.0
- Expanded the showup generation window from 7 to 10 days to ensure the full 7-day calendar strip is always covered with a DST-safe buffer; updated tests to assert the wider window

---

## [0.9.1] — 2026-04-10 (PR #15 merged)

### Changed — Lazy DateTime candidate generation in ShowupGenerator

- `_candidatesDaily`, `_candidatesWeekly`, `_candidatesMonthly`, and `_monthsInRange` converted from `List<DateTime>` builders to `sync*` / `yield` lazy `Iterable<DateTime>` generators
- New private dispatcher `_candidates(Pact)` routes to the correct generator based on schedule type
- `_generateInRange` and `_countInRange` now iterate lazily — no full-pact `DateTime` list is ever materialised, eliminating ~183 allocations per `DashboardViewModel.load()` call on a 6-month daily pact

---

## [0.9.0] — 2026-04-09 (PR #14 merged)

### Added — Lazy windowed showup generation + dynamic calendar strip

- `ShowupGenerator.generateWindow()` generates only showups within a configurable rolling window ahead of today instead of the full pact duration; `countTotal()` computes the total showup count without materialising all showups
- `ShowupGenerationService` encapsulates windowed generation logic and exposes `countShowupsForPact()` helper
- `PactStats` updated to accept a `totalShowups` override, enabling accurate stats using `countTotal()` rather than the persisted subset
- `PactDetailViewModel` uses `ShowupGenerator.countTotal()` for remaining/total counts so stats are accurate even when only a window of showups is persisted
- `DashboardViewModel` generates the next window on load and refreshes it lazily as the calendar scrolls into future dates
- Calendar strip `todayIndex` offset ramps gradually over the first 3 days (day 1: today at index 0, day 2: index 1, day 3: index 2, day 4+: centered at index 3) to avoid a visual jump when a pact is first created

---

## [0.8.0] — 2026-04-08 (PR #13 merged)

### Added — Showup detail screen

- `ShowupDetailState` and `ShowupDetailViewModel` (Riverpod `autoDispose` notifier) backed by `ShowupRepository`; loads showup and resolves the parent pact name for the header
- iOS (`CupertinoPageScaffold`) and Android (`Scaffold`) detail screens: shows scheduled time, habit name, and showup status with Done / Failed action buttons
- Auto-fail on open: if the screen is opened after the showup's scheduled window has passed (`now > scheduledAt + duration`), the showup is immediately persisted as `failed`; `nowProvider` is used so the clock is injectable and testable
- Save Note button disabled until the note content differs from the persisted value, preventing spurious writes
- Split error fields: `markError` for Done/Failed status mutations and `noteError` for note saves, so each action reports failures independently
- Localised `"(habit deleted)"` fallback displayed when the parent pact can no longer be found in the repository
- Dashboard showup tiles now carry a chevron and navigate to the detail screen; `nowProvider` invalidated on return so stale timestamps do not persist across navigations
- 12 new l10n keys across EN / FR / DE: `showupDetailTitle`, `showupDone`, `showupFailed`, `showupPending`, `markDone`, `markFailed`, `noteLabel`, `notePlaceholder`, `saveNote`, `markError`, `saveNoteError`, `habitDeleted`

---

## [0.7.1] — 2026-04-05 (PR #12 merged)

### Changed — Agent comment prefixes for distinguishability

- Tech Lead PR comments now prefixed with **[Tech Lead]** and Code Reviewer PR comments with **[Code Reviewer]** on all inline and general comments, so both agents' findings are distinguishable when reviewing in parallel

---

## [0.7.0] — 2026-04-05 (PR #11 merged)

### Added — Developer agent for TDD feature implementation

- Developer agent (`.claude/agents/developer.md`, model `claude-sonnet-4-6`) that implements work units produced by the Tech Lead agent following a strict TDD cycle (Red → Green → Refactor)
- Agent requires an approved Tech Lead implementation plan (read from Linear issue comments) before writing any code
- Branch naming convention enforced: `feature/HAB-XX-description`
- Full TDD cycle: write failing tests, implement minimum code to pass, refactor, run `flutter test` and `flutter analyze`
- Smoke test on both iOS and Android platforms required before opening a PR
- After pushing a PR the agent transitions the Linear issue to "In Review" and cues the orchestrator to invoke the Tech Lead and Code Reviewer agents in parallel for review
- Delegates `docs/ARCHITECTURE.md` updates to the Tech Lead agent and `docs/PRODUCT_SPEC.md` updates to the Product Owner agent; does not merge PRs (that remains the Product Owner's responsibility)

---

## [0.6.0] — 2026-04-05 (PR #10 merged)

### Added — Tech Lead agent and review wiring

- Tech Lead agent (`.claude/agents/tech-lead.md`, model `claude-opus-4-6`) that produces structured implementation plans from Linear issues: dependencies, models, UI changes, test strategy, ordered phases, and Developer work units
- `CLAUDE.md` workflow updated: step 1 now invokes the Tech Lead agent for large changes instead of producing plans inline; step 11 invokes tech-lead and code-reviewer in parallel (they check independent concerns — architectural vs runtime/launch)
- `model: claude-opus-4-6` field added to `tech-lead.md`; `model: claude-sonnet-4-6` added to `product-owner.md` and `code-reviewer.md` frontmatter
- `code-reviewer.md` updated with an explicit pre-reporting reasoning checklist (trigger sequence, existing handling, test coverage, worst-case outcome) — a finding is only reported when all four questions can be answered concretely
- `docs/AGENTS.md` updated to mark Phase 3 Done and record next actions

---

## [0.5.0] — 2026-04-04 (PR #9 merged)

### Added — Multi-agent workflow and Linear integration

- Product Owner agent (`.claude/agents/product-owner.md`) wired into session-start and post-merge workflow: reads Linear backlog, summarises released and remaining work, manages BACKLOG.md and CHANGELOG.md regeneration from Linear
- `.mcp.json` committed — Linear MCP server configured for the workspace, enabling all agents to query and update Linear issues
- `.claude/agents/` directory committed to the repository; `code-reviewer.md` (previously untracked) and `product-owner.md` now versioned
- `docs/AGENTS.md` describing the full multi-agent plan (Product Owner, Tech Lead, Developer, Code Reviewer)
- Backlog and changelog migrated to Linear as the single source of truth: `BACKLOG.md` is now generated from open Linear issues; `CHANGELOG.md` is maintained by the Product Owner agent after each merge
- HAB-10 (v0.5.0 milestone) closed as Done; milestone reached 100% completion

---

## [0.4.0] — 2026-04-04 (PR #7 merged)

### Added — Pact detail screen and persistent pacts panel

- Pact detail screen: stats (done / failed / remaining or cancelled / streak), timeline (start date, end date, days remaining), stop pact with confirmation dialog and optional explanation
- Pact detail screen is accessible for active, stopped, and completed pacts
- Persistent `DraggableScrollableSheet` panel on the dashboard listing all pacts with filter chips (Active / Done / Stopped) and a summary bar
- Tapping a pact tile navigates to its detail screen; returning refreshes both the pact list and the dashboard calendar
- Auto-completion: `PactDetailViewModel.load()` transitions an active pact to `completed` when its end date has passed (`daysLeft ≤ 0`) or all showups are resolved
- Locale-aware date and time formatting throughout (EN / FR / DE)
- Localised section headers (Stats, Timeline, Stop reason) in all three locales
- New l10n keys: `sectionStats`, `sectionTimeline`, `sectionStopReason`, `stopPactError`, `pactsActive`, `pactsDone`, `pactsCancelled`, `addPact`, `pactListTitle`, `filterActive`, `filterDone`, `filterCancelled`, `pactNextShowup`, `pactEndedOn`, `pactCancelledOn`

### Fixed

- `stopError` now displayed to the user when stopping a pact fails
- `TextEditingController` in stop dialogs wrapped in `try/finally` to guarantee disposal
- `assert(pact != null && stats != null)` added to `_PactDetailContent.build` on both platforms; defensive null guard retained for release mode
- Removed duplicate `pactListViewModelProvider.load()` — `DashboardScreen` owns all cold-start loads; `PactsPanel` is a pure observer
- Chevron removed from dashboard showup tiles (showup detail screen not yet implemented)
- Dashboard `getAllPacts()` used instead of `getActivePacts()` so pact names remain available across status transitions

### Tests

- 3 new tests for auto-completion: expired end date, all showups resolved, no-op (active with pending showups)

---

## [0.3.0] — 2026-04-03 (PR #5 merged)

### Added — Pact count warning and calendar dot layout

- Warning dialog before pact creation when the user already has 3 or more active pacts; plural-aware copy in EN/FR/DE
- iOS warning uses `CupertinoAlertDialog`; Android uses `AlertDialog`
- Crossfade animation when switching days in the calendar strip
- iOS nav-bar `+` button hidden on empty state (matching Android FAB behaviour)
- New l10n keys: `cancel`, `tooManyPactsTitle`, `tooManyPactsBody` (plural), `tooManyPactsConfirm`

### Changed — Calendar strip dot layout

- 1 showup → 1 dot; 2 → 2 dots on one row; 3 → 2+1 rows; 4+ → single large overflow dot
- Overflow dot colour: grey while any showup is still pending; green if all resolved and done ≥ failed; red if failed > done
- Overflow dot key includes date (`status-dot-overflow-YYYY-MM-DD`) to prevent key collisions across the 7-day strip

### Fixed

- TOCTOU race: `_creatingPact` flag prevents double-tap from bypassing the pact count guard
- `onCreatePact` typed as `AsyncCallback` so exceptions after `await` are not silently dropped
- `hasActivePactsProvider` now invalidated on return from pact creation via the warning-dialog path

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
