# Changelog

A record of all versioned releases. For planned work and known issues, see @docs/BACKLOG.md.

---

## [0.15.0] — 2026-05-03 (PR #45 merged)

### Added — SQLite mappers and codec (HAB-11 Work Unit 1)

- `lib/infrastructure/persistence/schedule_codec.dart` — JSON codec for `ShowupSchedule` supporting all three schedule types (`daily`, `weekly`, `monthly`); encodes to a plain `Map<String, dynamic>` suitable for SQLite text columns
- `lib/infrastructure/persistence/pact_mapper.dart` — bidirectional mapper between `Pact` domain model and SQLite row (`Map<String, dynamic>`); handles all nullable fields and delegates schedule serialisation to `ScheduleCodec`
- `lib/infrastructure/persistence/showup_mapper.dart` — bidirectional mapper between `Showup` domain model and SQLite row; handles `ShowupStatus` and `Duration` round-trips
- `docs/ARCHITECTURE.md` updated with `persistence/` directory tree entry and Persistence paragraph describing the mapper/codec layer
- `AGENTS.md` step 3 updated: branch must be created from `origin/main`
- 561 tests passing, analyzer clean

---

## [0.14.0] — 2026-05-03 (PR #44)

### Changed — Single-ticket workflow, pre-merge housekeeping, CI version-tag fix

- `AGENTS.md`: only one ticket may be in progress at a time; `docs/BACKLOG.md` `## In Progress` section signals the active ticket; step 3 marks the ticket there when the branch is created; step 16 revised — product-owner commits CHANGELOG + BACKLOG + pubspec bump onto the feature branch *before* merge so all housekeeping lands in one squash commit; version bump no longer requires user approval
- `docs/BACKLOG.md`: `## In Progress` section added at the top; HAB-47 and HAB-49 removed from Unscheduled (merged)
- `.github/workflows/ci.yml` `version-tag` job: `git pull --rebase` moved to *before* the `sed`/commit instead of after — eliminates the rebase conflict when a prior build-number bump landed on main while the job was waiting for distribute steps to finish

---

## [0.13.0] — 2026-05-03 (PR #42 + PR #43)

### Added — Experiment registry and experimentation stack documentation (HAB-49)

- `docs/experiments/README.md` added: index table of all experiments (empty to start), status definitions (`running`, `won`, `lost`, `abandoned`), and a step-by-step "Starting an experiment" protocol with ID numbering convention
- `docs/experiments/TEMPLATE.md` added: per-experiment file template covering hypothesis, setup, primary and guardrail metrics, audience, ramp plan, stop rule, decision, and learnings; status field defaults to `running`
- `docs/ARCHITECTURE.md` updated with a brief mention of `docs/experiments/` as the experiment registry location
- `AGENTS.md` updated: documentation table entry for the registry; new Experiments section describing how agents should update the registry when an experiment concludes; clarification that Firebase A/B Testing is console-only (no extra SDK needed)
- Default experimentation stack defined: Firebase Remote Config + Firebase A/B Testing for the near term, with explicit criteria for when to evaluate dedicated tools (Statsig, LaunchDarkly, or PostHog)

### Changed — Logging infrastructure and deepened Crashlytics instrumentation (HAB-47)

- `talker_flutter`-based `LogService` abstraction introduced in `lib/infrastructure/logging/`: `TalkerLogService` (in-app overlay in debug mode), `NoopLogService` (for tests), and a Riverpod `logServiceProvider`
- `CrashlyticsService` extended with `setCustomKey(String key, Object value)` — implemented in `FirebaseCrashlyticsService`, `NoopCrashlyticsService`, and `FirebaseCrashlyticsClientAdapter`
- `main.dart` wired to instantiate Talker, override `logServiceProvider` in debug builds, and set `locale` and `app_session_start_time` custom Crashlytics keys on startup
- Breadcrumb `crashlyticsService.log()` calls added in `DashboardViewModel`, `PactCreationViewModel`, `PactDetailViewModel`, and `ShowupDetailViewModel` on load and user actions; `recordError` added in catch blocks for non-fatal exception capture
- PII rules enforced: user-entered text (habit names, notes, stop reasons) logged only as `field.length=N`; IDs, timestamps, counts, and enum values logged freely
- 497 tests pass, analyzer clean

---

## [0.12.0] — 2026-05-01 (PR #41 merged)

### Changed — DDD-style layered architecture refactor (HAB-45)

- `lib/features/` renamed to `lib/slices/`; all import sites updated to canonical paths
- `lib/domain/` introduced as a top-level directory for pure domain models and repository interfaces shared across slices (`pact/`, `showup/`)
- `lib/infrastructure/` groups all cross-cutting services (`analytics/`, `crashlytics/`, `remote_config/`); each service's `domain/` subdirectory renamed to `contracts/` to avoid shadowing the top-level `lib/domain/`
- `PactBuilder`, `PactCreationState`, and `PactStatsService` moved from `slices/pact/domain/` to `slices/pact/application/`
- `ShowupGenerationService` moved from `slices/showup/domain/` to `slices/showup/application/`
- `ScheduleType` enum extracted from `PactBuilder` to `lib/domain/pact/schedule_type.dart`
- UI state classes (`DashboardState`, `PactDetailState`, `PactListState`, `ShowupDetailState`) moved from slice `domain/` to their respective `ui/generic/` directories
- All re-export stubs removed; every import site updated to the canonical file path
- Zero logic changes; 469 tests pass, analyzer clean

---

## [0.11.11] — 2026-04-30 (PR #40 merged)

### Fixed — iOS cold-start white screen (HAB-44)

- `LaunchScreen.storyboard` background changed from white to brand teal (`#00637B`); transparent foreground icon (from Android adaptive icon layer) replaces the flat opaque icon — logo now floats seamlessly on the teal background, matching Android's splash screen
- `Main.storyboard` root view background changed from white to teal (`#00637B`) — eliminates the white flash during Firebase init between launch screen dismissal and first Flutter frame
- `SceneDelegate.swift` sets `UIWindow.backgroundColor` to teal (`#00637B`) — closes the last remaining white gap caused by the UIKit window default white showing through the transparent `FlutterViewController` view during engine init
- `dashboard_page_ios.dart`: removed `ColoredBox(systemBackground)` that forced white on the calendar strip and showup list while the nav bar and `PactsPanel` used `colorScheme.surface` (mint); set `CupertinoListTile.backgroundColor` to transparent for full visual consistency
- `ios/Podfile.lock`: `firebase_remote_config` and `FirebaseABTesting` pods added (were missing despite being declared in `pubspec.yaml` since v0.10.3)
- 469 tests pass, analyzer clean

---

## [0.11.10] — 2026-04-29 (HAB-17)

### Refactored — Extract PactBuilder from PactCreationState (HAB-17)

- `PactBuilder` introduced in `lib/features/pact/domain/pact_builder.dart`: owns the 7 pact-data fields (`habitName`, `startDate`, `endDate`, `showupDuration`, `scheduleType`, `schedule`, `reminderOffset`), the `_addMonths` month-clamping helper, and the `ScheduleType` enum; exposes validity predicates (`isDateRangeValid`, `isShowupDurationValid`, `isScheduleSet`, `isHabitNameValid`, `isComplete`) and a `build({id, createdAt})` factory that throws `StateError` if incomplete
- `PactCreationState` slimmed to wizard-navigation concerns only: holds `builder: PactBuilder`, `currentStep`, `commitmentAccepted`, `isSubmitting`, `submitError`; data-field params removed from `copyWith`; proxy getters (`habitName`, `startDate`, etc.) delegate to `builder` so zero widget changes were needed; `canAdvanceFromStep` is now a pure dispatch table routing each step to the corresponding builder predicate
- `PactCreationViewModel` gains private `_updateBuilder()` helper; all data-field setters route through it; `submit()` guard replaced with `if (!state.builder.isComplete) return;` and manual `Pact(...)` constructor replaced with `state.builder.build(id: ..., createdAt: now)`
- `ScheduleType` re-exported from `pact_creation_state.dart` so all existing import sites remain unchanged
- 43 new `PactBuilder` tests; `PactCreationState` tests rewritten to cover dispatch-table delegation and proxy-getter correctness; 468 tests pass, analyzer clean

---

## [0.11.9] — 2026-04-27 (PR #36 merged)

### Added — iOS builds wired to Firebase App Distribution (HAB-28)

- `build-ios` job added to `.github/workflows/ci.yml` running on `macos-latest`; builds a release IPA using the Apple distribution certificate and ad-hoc provisioning profile stored as GitHub Actions secrets (`IOS_CERTIFICATE_P12`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE`, `IOS_TEAM_ID`)
- `distribute-ios` job added; uploads the signed IPA to Firebase App Distribution using the `FIREBASE_IOS_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_IOS` secrets, running on every merge to `main` only
- `version-tag` job updated to emit `both`, `android`, or `ios` suffix depending on which platform builds succeeded, and pinned to the triggering commit SHA to close a race window where a concurrent build-number bump could cause the tag to target the wrong commit
- `docs/VERSIONING.md` updated with the `FIREBASE_IOS_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_IOS` secrets, the revised CI pipeline diagram, and the race-window fix explanation

---

## [0.11.8] — 2026-04-27 (PR #38 merged)

### Fixed — CupertinoDynamicColor dark-mode resolution in ShowupStatusColors (HAB-41)

- `ShowupStatusColors.cupertino` const factory removed; both iOS dashboard call sites now resolve `CupertinoColors.activeGreen`, `CupertinoColors.destructiveRed`, and `CupertinoColors.systemGrey` via `resolveFrom(context)` before passing them to the `ShowupStatusColors` constructor, restoring correct light/dark adaptation for calendar-strip dots and showup tile icons in iOS dark mode
- 404 tests pass, analyzer clean

---

## [0.11.7] — 2026-04-27 (PR #37 merged)

### Changed — Extract shared formatLocaleDate helper to eliminate six-site duplication (HAB-42)

- `formatLocaleDate(BuildContext context, DateTime date)` helper added to `lib/l10n/date_formatters.dart` as the single canonical definition of the `DateFormat.yMd(locale).format(date)` pattern
- All six previous call sites unified: inline usages in `pact_duration_step_ios.dart`, `pact_duration_step_android.dart`, `pact_detail_page_ios.dart`, and `pact_detail_page_android.dart` replaced; `formatPactDate` in `pact_creation_formatters.dart` and `formatShowupDate` in `showup_formatters.dart` delegated to the shared helper
- `docs/ARCHITECTURE.md` updated to document `lib/l10n/date_formatters.dart`
- 402 tests pass, analyzer clean

---

## [0.11.6] — 2026-04-26 (PR #35 merged)

### Fixed — Align pubspec.yaml version name with changelog (HAB-43)

- `pubspec.yaml` version name bumped from `0.1.0` to `0.11.5` so Firebase App Distribution labels builds with the correct version instead of the initial scaffold value
- `AGENTS.md` workflow updated: step 10 now requires verifying that `pubspec.yaml` version name matches the latest `CHANGELOG.md` entry before committing, and updating it (with user approval) when a new changelog entry is added
- 399 tests pass, analyzer clean

---

## [0.11.5] — 2026-04-25 (PR #34 merged)

### Changed — Reduce duplicated iOS/Android dashboard widget logic (HAB-15)

- Extracted shared formatter helpers — `pact_creation_formatters.dart`, `pact_formatters.dart`, `showup_formatters.dart` — replacing duplicated date, schedule, reminder, and status formatting logic across commitment steps, schedule steps, pact detail pages, showup detail pages, and the pacts summary bar
- Extracted `ShowupStatusColors` — a platform-agnostic colour-role resolver with Cupertino and Material factory constructors, replacing inline status-colour switches in both dashboard pages and showup tile implementations
- Extracted `ShowupStatusDots` — a platform-agnostic calendar-strip dot widget encapsulating the 1/2/3/4+ overflow layout and key naming, replacing `_buildDots()` in both dashboard pages
- Extracted `SummaryRow` — a platform-agnostic two-column label/value row for the commitment step summary card, replacing `_SummaryRow` in both commitment step files
- `docs/ARCHITECTURE.md` updated to document the expanded `generic/` responsibilities
- 399 tests pass, analyzer clean, dart format clean

---

## [0.11.4] — 2026-04-21 (PR #33 merged)

### Changed — Code quality baseline and dart format enforcement (HAB-33)

- 13 lint rules added to `analysis_options.yaml` covering readability (`always_declare_return_types`, `avoid_print`, `prefer_single_quotes`, etc.), safety (`avoid_dynamic_calls`, `cast_nullable_to_non_nullable`), and Flutter-specific concerns (`use_build_context_synchronously`, `sized_box_for_whitespace`)
- `dart format --line-length 120` applied across the entire codebase in a dedicated formatting commit, keeping style-only changes separate from functional work
- CI (`github/workflows/ci.yml`) gains a `dart format --output=none --set-exit-if-changed` check on every push and PR, excluding generated files (`firebase_options.dart`, `lib/l10n/generated/*`)
- `AGENTS.md` and `.claude/agents/developer.md` updated to require a formatting commit (separate from functional commits) as part of the standard ticket delivery workflow; worktree-per-issue convention documented throughout

---

## [0.11.3] — 2026-04-21 (PR #32 merged)

### Changed — Per-app language selection (HAB-39)

- `CFBundleLocalizations` array added to `ios/Runner/Info.plist` listing `en`, `fr`, `de`, so iOS Settings shows a per-app language picker under the app's entry (iOS 13+)
- `android/app/src/main/res/xml/locales_config.xml` created with the three supported locales and referenced via `android:localeConfig` on the `<application>` element in `AndroidManifest.xml` (Android 13+ / API 33; older versions are unaffected)
- No Dart changes required — Flutter's existing `AppLocalizations` setup already handles locale switching once the platform declarations are in place

---

## [0.11.2] — 2026-04-21 (PR #31 merged)

### Changed — Dark mode support (HAB-37)

- `darkMaterialTheme` added to `HabitLoopTheme` using Material3 container tokens so all surfaces, text, and icons adapt automatically to the system colour scheme
- `ThemeMode.system` wired into `MaterialApp` so the app follows the device's light/dark preference without any manual toggle
- `CupertinoTheme` brightness propagated from the active `BuildContext` so iOS widgets also respond correctly to dark mode
- All hardcoded non-adaptive colours replaced with Material3 container tokens across Android widgets (Dashboard, Pact creation wizard, Pact detail, Showup detail, pacts panel, calendar strip, status dots, tiles)

---

## [0.11.1] — 2026-04-21 (PR #30 merged)

### Changed — Lock app to portrait orientation (HAB-38)

- `Info.plist` updated to list only `UIInterfaceOrientationPortrait` in `UISupportedInterfaceOrientations` (iPhone), so iOS phones stay portrait-only regardless of device rotation
- iPad landscape support preserved in `UISupportedInterfaceOrientations~ipad` to comply with App Store guideline 10.1, which requires iPad apps to support both landscape orientations
- `AndroidManifest.xml` `MainActivity` entry updated with `android:screenOrientation="portrait"` so Android devices remain locked to portrait

---

## [0.11.0] — 2026-04-20 (PR #29 merged)

### Fixed — iOS home indicator gesture on dashboard bottom sheet (HAB-36)

- Removed the invisible gesture-blocking overlay that was preventing the native iOS swipe-up home gesture while the dashboard bottom sheet was visible; the `DraggableScrollableSheet` now receives gestures correctly without any custom bottom reserve
- The mint safe-area visual treatment (achieved via `CupertinoPageScaffold.backgroundColor`) is preserved, so no white stripe reappears below the bottom sheet
- Focused widget test added to `dashboard_page_ios_test.dart` asserting that no custom home-indicator reserve or blocking overlay is present in the widget tree

---

## [0.10.4] — 2026-04-19 (PR #28 merged)

### Added — App design foundation and launcher icon (HAB-35)

- Shared Habit Loop visual foundation added in `lib/theme/`: Material and Cupertino themes now use the same teal/growth/sunrise palette, and pact status colors consume semantic app colors instead of ad-hoc Material defaults
- New Habit Loop app icon source added under `assets/app_icon/` and integrated into iOS and Android launcher assets, using the approved original icon composition with opaque iOS PNGs
- Android adaptive launcher icon and splash screen now share the same teal background color and tuned foreground sizing so the icon fills the launcher surface without the previous visible clipping
- iOS pact creation now includes a small step indicator using the shared palette, improving consistency with the newly defined app visual language
- iOS dashboard keeps the bottom safe-area visually aligned with the mint bottom sheet via the scaffold background, with focused test coverage documenting that no custom home-indicator overlay or reserve is used
- `docs/ARCHITECTURE.md` updated to document the shared theme layer and app icon asset source; tests added for the theme, iOS pact creation step indicator, and iOS dashboard safe-area treatment

---

## [0.10.3] — 2026-04-19 (PR #27 merged)

### Added — Firebase Remote Config integration (HAB-25)

- `firebase_remote_config` SDK added to `pubspec.yaml`; a new `remote_config/` vertical slice introduces `RemoteConfigService` (abstract interface with a no-throw contract), `FirebaseRemoteConfigService` (backed by `FirebaseRemoteConfigClientAdapter`), and `NoopRemoteConfigService` for debug/profile builds
- `RemoteConfigDefaults` class acts as the single source of truth for all default values; `max_active_pacts` defaults to `3`
- `remoteConfigServiceProvider` wired via Riverpod so the service can be overridden in tests; `main.dart` constructs the adapter, calls `initialize()`, and overrides the provider under `kReleaseMode`
- Dashboard pact-count warning threshold replaced: hardcoded `>= 3` replaced with `remoteConfigServiceProvider.getInt('max_active_pacts')`, making the limit remotely configurable without a new release
- `tooManyPactsBody` l10n updated across EN/FR/DE to be plural-aware on the limit value (not the existing count), so copy is grammatically correct when `max_active_pacts = 1`
- `docs/ARCHITECTURE.md` updated with `remote_config/` directory tree, Layers section, and `firebase_remote_config` dependency
- 361 tests passing, analyzer clean

---

## [0.10.2] — 2026-04-18 (PR #25 merged)

### Fixed — startDate normalization and injectable now in pact detail (HAB-34)

- `PactCreationState` constructor and `PactCreationViewModel.setStartDate()` now normalize `startDate` to midnight, preventing a wall-clock time component from causing `duration_days` in `pact_created` analytics to under-count by 1 and `daysActive` in `pact_stopped` to report 0 when a pact is stopped the morning after an evening creation
- `pactDetailNowProvider` (`Provider<DateTime>`) extracted and wired into both `load()` (auto-completion check) and `stopPact()` (analytics), matching the `showupDetailNowProvider` and `pactCreationTodayProvider` pattern; `PactDetailScreen.initState()` and `onStopPact()` both invalidate the provider before use so the clock is always fresh

---

## [0.10.1] — 2026-04-18 (PR #21 merged)

### Fixed — Pact stats and dashboard analytics fixes (HAB-30, HAB-31, HAB-32)

- `pact_created` analytics now reports inclusive `duration_days`, aligning daily 6-month pact duration semantics with `showups_expected` and removing the apparent off-by-one mismatch
- Stopped pacts now preserve historical showup stats after active showups are deleted, and showup status changes refresh persisted pact stats through a single service boundary
- Dashboard `screen_view` analytics now fire every time the dashboard becomes visible again after returning from pact creation, pact detail, or showup detail flows

## [0.10.0] — 2026-04-17 (PR #20 merged)

### Added — Firebase Crashlytics integration (HAB-29)

- `firebase_crashlytics` SDK added to `pubspec.yaml`; a new `crashlytics` vertical slice introduces `CrashlyticsService` (abstract interface with a strict no-throw contract), `FirebaseCrashlyticsService` (backed by `FirebaseCrashlyticsClientAdapter`), and `NoopCrashlyticsService`
- `FlutterError.onError` and `PlatformDispatcher.instance.onError` wired to Crashlytics in `main.dart` so both Flutter-layer and native crashes are captured in release builds; debug and profile builds fall back to `NoopCrashlyticsService`
- `crashlyticsServiceProvider` provided via Riverpod so the service can be overridden in tests; `FakeCrashlyticsService` in `test/crashlytics/` for dependency injection
- `NoopAnalyticsService` and `NoopCrashlyticsService` now log via `debugPrint` in debug/profile builds for easier local debugging
- `Pact.createdAt` field added; `ShowupGenerationService.ensureShowupsExist` and `ShowupGenerator.countTotal` now respect it to prevent past-due intra-day showups from being resurrected on dashboard load or causing a ghost "1 remaining" in pact stats
- `ARCHITECTURE.md` corrected: raw `FirebaseCrashlytics` SDK is referenced both via the adapter and directly in pre-`runApp` error handlers

---

## [0.9.5] — 2026-04-11 (PR #19 merged)

### Added — Firebase Analytics integration (HAB-26)

- `firebase_analytics` SDK added to `pubspec.yaml`; a new `analytics` vertical slice introduces `AnalyticsService` (abstract interface), `FirebaseAnalyticsService` (backed by `FirebaseAnalyticsClientAdapter`), and `NoopAnalyticsService` — infrastructure only, no widgets
- Per-vertical `analytics/` packages: `pact/analytics/` contains `PactCreatedEvent` and `PactStoppedEvent`; `showup/analytics/` contains `ShowupMarkedDoneEvent`, `ShowupMarkedFailedEvent`, and `ShowupAutoFailedEvent` — events live next to the domain they describe
- Events tracked: `pact_created` (schedule type, duration days, showup duration minutes, reminder offset, showups expected), `pact_stopped` (days active, done/failed/remaining counts), `showup_marked_done`, `showup_marked_failed`, `showup_auto_failed`
- Screen views tracked via `AnalyticsScreen` enum on dashboard, pact creation, pact detail, and showup detail screens
- `kReleaseMode` guard in `main.dart`: debug/profile builds inject `NoopAnalyticsService`; only release builds wire `FirebaseAnalyticsService`
- `analyticsServiceProvider` provided via Riverpod so the service can be overridden in tests
- All analytics failures are swallowed in view models so analytics can never surface errors to the user
- `FakeAnalyticsService` in `test/features/analytics/` for dependency injection; `PactCreationViewModel`, `PactDetailViewModel`, and `ShowupDetailViewModel` tests assert correct events are fired with the right parameters (290 tests passing)

---

## [0.9.4] — 2026-04-11 (PR #18 merged)

### Added — Android CI/CD pipeline with Firebase App Distribution (HAB-20)

- GitHub Actions `distribute-android` job updated to upload the Android AAB to Firebase App Distribution on every merge to `main` using the Firebase App Distribution GitHub Action
- `FIREBASE_APP_ID_ANDROID` and `FIREBASE_TOKEN` GitHub Actions secrets wired into the workflow; build artifacts flow from the `build-android` job via uploaded artifacts
- Distribution only runs on the `main` branch; feature branch builds continue to build without distributing or tagging

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
