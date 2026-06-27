# Changelog

A record of all versioned releases. For planned work and known issues, see @docs/BACKLOG.md.

---

## [0.46.2] — 2026-06-27

### Changed — Meta

- [meta] HAB-116 debrief: knowledge base entry from Linear comments

---

## [0.46.1] — 2026-06-27

### Changed — Meta

- [meta] HAB-128 debrief: per-language canonical terms table filled in GLOSSARY.md; What's New style guardrails with examples added to ship skill

---

## [0.46.0] — 2026-06-27

### Changed — Localisation

- [user] HAB-128: improved translation consistency in French, German, and Russian
- [app] HAB-128: showup → séance (FR), явка (RU), Showup (DE); Zeitleiste → Verlauf (DE); Fait → Réalisé (FR); beenden → stoppen (DE)

---

## [0.45.15] — 2026-06-27 (PR #195 merged)

### Changed — Meta

- [meta] HAB-130 debrief: knowledge base entry + `/debrief` always creates branch+PR

---

## [0.45.14] — 2026-06-27

### Changed — Meta

- [meta] HAB-130 WU2: `/debrief` writes retrospective to `docs/knowledge/notes/HAB-XX.md`; fix stale `docs/WORKFLOW.md` reference

---

## [0.45.13] — 2026-06-27 (PR #193 merged)

### Added — Meta

- [wip] HAB-130 WU1: knowledge vault (`docs/knowledge/`), `/note` skill, and slash command stub

---

## [0.45.12] — 2026-06-27 (PR #191 merged)

### Changed — CI

- [ci] HAB-134: configurable workflow_dispatch inputs (android/ios/environment/deploy); dispatch_plan.py wired into check-skip; build and distribute jobs gated on per-platform flags; group_alias driven by environment input

---

## [0.45.11] — 2026-06-27 (PR #190 merged)

### Changed — CI

- [wip] HAB-134 WU1: dispatch_plan.py decision helper + unit tests (build/distribute flag computation for configurable workflow_dispatch runs)

---

## [0.45.10] — 2026-06-27 (PR #189 merged)

### Changed — Skills

- [meta] Added "Mirror, don't lead" and "The user's responsibility" principles to shared dialog guidelines (HAB-136)

---

## [0.45.9] — 2026-06-27 (PR #188 merged)

### Changed — CI

- [ci] Build and distribution are now skipped entirely when the newest CHANGELOG entry contains no `[user]` or `[app]` bullets; `version-*-none` tag eliminated

---

## [0.45.8] — 2026-06-27 (PR #185 merged)

### Changed — Pact Timeline

- [user] Recent showups are now shown individually for the past 7 days, so you always see each day clearly no matter how consistent your streak has been
- [app] Section header updated from "The most recent showups" to "Showups from the last N days" in all four locales

---

## [0.45.7] — 2026-06-26 (PR #184)

### Changed — Workflow

- [meta] Split docs/WORKFLOW.md into FEATURE_WORKFLOW.md (feature development) and TROUBLESHOOT_WORKFLOW.md (bugs, CI failures, infrastructure issues); each file cross-references the other
- [meta] TROUBLESHOOT_WORKFLOW captures lessons from HAB-132: open a ticket before the second fix attempt; include OSS health checks in trade-off analysis

---

## [0.45.6] — 2026-06-26 (PR #183)

### Changed — CI

- [ci] Replace firebase-tools `appdistribution:distribute` with direct Firebase App Distribution REST API calls (gcloud auth + curl) — eliminates the firebase-tools auth problem entirely; root cause was an explicit `@13` pin that predated v14's ADC fix
- [ci] Switch download-artifact to v8.0.1 (Node 24 native)
- [ci] Enable `workflow_dispatch` builds from feature branches for Android-only test runs without merging to main

---

## [0.45.5] — 2026-06-26 (PR #182)

### Changed — CI

- [ci] Use google-github-actions/auth@v2 to set up Application Default Credentials — replaces manual GOOGLE_APPLICATION_CREDENTIALS wiring which firebase-tools 13.x does not pick up reliably

---

## [0.45.4] — 2026-06-26 (PR #181)

### Changed — CI

- [ci] Activate service account via gcloud before firebase distribute — workaround for firebase-tools not picking up GOOGLE_APPLICATION_CREDENTIALS on GitHub Actions runners

---

## [0.45.3] — 2026-06-25 (PR #180)

### Changed — CI

- [ci] Revert Firebase App Distribution auth back to service account JSON (GOOGLE_APPLICATION_CREDENTIALS); add JSON validation step to catch malformed secret values early; FIREBASE_TOKEN approach deprecated by firebase-tools

---

## [0.45.2] — 2026-06-25 (PR #179)

### Changed — CI

- [ci] Switch Firebase App Distribution auth from service account JSON (GOOGLE_APPLICATION_CREDENTIALS) to FIREBASE_TOKEN — the previous approach broke on June 25

---

## [0.45.1] — 2026-06-25 (HAB-116 debrief)

### Changed — Workflow and skill improvements

- [meta] brief skill: add visual alignment step (ASCII mockup) for UI-heavy features before ticket creation
- [meta] plan skill: clarify scenario-timing language — "filled in WUN" for scenarios blocked on later-WU UI
- [meta] workflow: add algorithm + pagination compatibility check to plan phase; add [wip] CHANGELOG tag guidance for intermediate WU merges
- [ci] changelog lint: register [wip] as a valid classification tag (skips build and distribution; preserves release-notes aggregation)
- [meta] versioning: document [wip] tag behaviour and its interaction with release-notes accumulation

---

## [0.45.0] — 2026-06-25 (HAB-129, PR #177)

### Fixed — Timeline QA fixes

- [user] Isolated showups in the history section are now tappable and editable — previously a single showup rendered as a non-interactive streak label
- [app] Date formatter now respects the OS Region setting when the app language has no country code (e.g. plain "English") — dates now show in the correct regional order (dd/MM/yyyy for European regions)

---

## [0.44.14] — 2026-06-25 (HAB-116 WU7, PR #176)

### Added — Pact timeline screen (Android)

- [user] Pact timeline screen is now available on Android — tap "View Timeline" on the pact detail screen to see the full history of a pact
- [user] Timeline shows all milestone types: pact creation, showup streaks, groups, individually-noted showups, tail-zone single showups, and the current state or conclusion
- [user] Tapping a noted showup or a single tail-zone showup opens the showup detail screen
- [app] `PactTimelinePageAndroid` — Material spine layout with golden-ratio columns, section-header divider, and locale-aware dates; mirrors the iOS design
- [app] `PactDetailPageAndroid` now accepts `pactTimelineEnabled` + `onOpenTimeline`; entry-point button gated behind `pact_timeline_enabled` Remote Config flag

---

## [0.44.13] — 2026-06-24 (HAB-116 WU6.2, PR #175)

### Changed — Pact timeline fixes (iOS)

- [user] Timeline dates now match the regional date format of the device (e.g. European devices show day-first ordering)
- [user] Each timeline row now shows the date on the left and the milestone label on the right, making them easier to tell apart at a glance — applies to all milestone types
- [app] `CurrentStateMilestone.showupsRemaining` now reflects the total schedule remaining (`ShowupGenerator.countTotal − done − failed`) rather than the count of already-generated pending showups
- [app] `pact_timeline_milestone_grouping_threshold` default reduced from 10 to 1; RC int-range min reduced from 10 to 1; `pact_timeline_enabled`, `pact_timeline_milestone_grouping_threshold`, and `pact_timeline_no_grouping_tail_size` added to Firebase Remote Config
- [app] All milestone date strings are now italic, including anchor milestones (Pact Created, Current State, Pact Concluded)

---

## [0.44.12] — 2026-06-24 (HAB-116 WU6.1, PR #174)

### Changed — Pact timeline visual redesign (iOS)

- [user] Timeline milestones now display on a continuous vertical spine with a gradient line connecting colored dots — green for done, red for failed, grey for mixed/pending, teal for anchor milestones
- [user] Each milestone shows its date or date range above the status label, making the chronological structure easier to scan
- [user] A "The most recent showups" section header separates the individually-shown tail-zone showups from grouped milestones above
- [user] Returning from a showup detail screen now immediately refreshes the timeline, reflecting any status change without re-opening
- [app] `PactTimelinePageIos` rebuilt with `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)` spine layout and a `CustomPainter` gradient spine line
- [test] Fixed four pre-existing integration test failures in `archive_pact_flow_test.dart` and `pact_note_flow_test.dart` caused by the View Timeline button (added in WU6) pushing archive/save buttons below the ListView viewport

---

## [0.44.11] — 2026-06-23 (HAB-116 WU6, PR #173)

### Application — Pact timeline iOS UI

- [user] Pact detail screen now shows a "View Timeline" button (gated on `pact_timeline_enabled` Remote Config flag); tapping opens the new pact timeline screen
- [user] iOS pact timeline screen: displays all pact milestones in chronological order — pact-created anchor, showup streaks, showup groups, noted showups, single tail-zone showups, and a current-state or pact-concluded anchor
- [user] Noted showups and single tail-zone showups are tappable and open the existing showup detail screen
- [app] `PactTimelineScreen`: new `ConsumerStatefulWidget` orchestrator; fires `pact_timeline` screen-view analytics in `initState`; delegates to `PactTimelinePageIos` on iOS
- [app] `PactTimelinePageIos` + `pact_timeline_formatters.dart`: iOS page widget and pure label/date-range builders for each milestone type
- [app] `PactTimelineOpenedEvent`: new companion analytics event (`pact_timeline_opened`) fired from `PactTimelineViewModel.load()` after successful load; carries `pact_id`, `pact_status`, `milestone_count`

---

## [0.44.10] — 2026-06-23 (HAB-116 WU5, PR #172)

### Application — PactTimelineViewModel

- [app] `PactTimelineState`: new state class; holds `anchorStart`, `anchorEnd`, `milestones` (full grouped list), `isLoading`, `loadError`
- [app] `PactTimelineViewModel`: new `FamilyNotifier` with `load()` (evicts cache, fetches and exposes the full milestone list — no display windowing; grouper compaction is sufficient) and `onMilestoneTapped()` (fires `PactTimelineMilestoneTappedEvent`)
- [app] `pactTimelineViewModelProvider`: new `NotifierProviderFamily<PactTimelineViewModel, PactTimelineState, String>` keyed by `pactId`
- [app] `pactTimelineNowProvider`: new overridable `Provider<DateTime>` for deterministic `CurrentStateMilestone.sortAt` in tests

---

## [0.44.9] — 2026-06-22 (HAB-116 WU4, PR #171)

### Application — PactTimelineCache

- [app] `PactTimelineCache`: new session-scoped in-memory showup cache in `slices/pact/application/`; `Map<String, List<Showup>>` keyed by `pactId`; `get`, `populate`, `evict` API
- [app] `pactTimelineCacheProvider`: new standalone Riverpod provider in `app_providers.dart`; injected into `pactTimelineServiceProvider`; eviction wired from the ViewModel (WU5)
- [app] `PactTimelineService`: now injects `PactTimelineCache`; `loadAll` checks the cache before hitting the DB and populates it on miss

---

## [0.44.8] — 2026-06-22 (HAB-116 WU3, PR #170)

### Application — PactTimelineService assembler

- [app] `PactTimelinePage`: new value object in `slices/pact/application/` holding `anchorStart` (`PactCreatedMilestone`), `anchorEnd` (`CurrentStateMilestone` or `PactConcludedMilestone`), and `milestones` (all grouped showup milestones, oldest-first)
- [app] `PactTimelineService`: new service in `slices/pact/application/`; `loadAll(pactId)` loads all showups, sorts them, groups via injected `PactTimelineGrouper`, and assembles a complete `PactTimelinePage`; no caching (WU4); display windowing is a VM concern (WU5)
- [app] `PactTimelineConfig`: removed `firstPageSize` / `nthPageSize` — pagination is not a service-layer concern; removed the corresponding RC defaults
- [app] `pactTimelineServiceProvider`: new Riverpod provider in `app_providers.dart`; constructs `PactTimelineGrouper` from RC config (sentinel `noGroupingTailSize=0` → defaults to `groupingThreshold`) and injects it

---

## [0.44.7] — 2026-06-22 (HAB-116 WU2, PR #169)

### Domain — PactTimelineMilestone sealed union + PactTimelineGrouper

- [app] `PactTimelineMilestone`: new sealed class in `slices/pact/application/` with seven variants — `PactCreatedMilestone`, `ShowupStreakMilestone`, `SingleShowupMilestone`, `ShowupGroupMilestone`, `NotedShowupMilestone`, `CurrentStateMilestone`, `PactConcludedMilestone`; each carries a `sortAt` key for oldest-first ordering
- [app] `PactTimelineGrouper`: pure, dependency-free class in `slices/pact/application/`; constructor params `groupingThreshold` and `noGroupingTailSize` (defaults to `groupingThreshold` via initializer list); `group(showups)` produces showup-derived milestones — streak items (≥ threshold), group items (mixed/short, < threshold), individual `SingleShowupMilestone` per tail-zone showup, `NotedShowupMilestone` for any noted showup; pending showups are filtered before processing

---

## [0.44.6] — 2026-06-22 (HAB-116 WU1, PR #168)

### Config — pact timeline RC params, FeatureFlags, PactTimelineConfig, analytics event classes

- [app] `RemoteConfigDefaults`: add `pact_timeline_enabled` (default `true`), `pact_timeline_milestone_grouping_threshold` (default `10`), `pact_timeline_no_grouping_tail_size` (default `10`), `pact_timeline_first_page_size` (default `20`), `pact_timeline_nth_page_size` (default `10`); add bounded `intRanges` for all four params and for `max_active_pacts`; change `allowedValues` and `intRanges` to non-nullable-value maps (absent key = no constraint)
- [app] `FeatureFlags`: add `pactTimelineEnabled` getter
- [app] `PactTimelineConfig`: new class in `slices/pact/application/`; reads five RC params directly (no sentinel resolution)
- [app] `pact_timeline_analytics_events.dart`: add `PactTimelineAnalyticsScreen`, `PactTimelineLoadMoreEvent`, `PactTimelineMilestoneTappedEvent`
- [app] `docs/FEATURE_TOGGLES.md`: add `pact_timeline_enabled` row

---

## [0.44.5] — 2026-06-21 (HAB-116, PR #167)

### Tests — HAB-116 WU0: pact timeline screen integration scenarios

- [test] `integration_test/pact_timeline_flow_test.dart`: 9 scenario stubs covering timeline navigation, anchor events, grouping algorithm (group item, streak item, noted showup, tail zone), pagination with load-more analytics, tappable single-showup, and kill-switch flag-off
- [meta] `docs/ANALYTICS_EVENTS.md`: add `PactTimelineAnalyticsScreen`, `pact_timeline_load_more`, and `pact_timeline_milestone_tapped` entries (approved analytics plan for HAB-116)
- [meta] `docs/ARCHITECTURE.md`: document `PactTimelineConfig`, `PactTimelineGrouper`, `PactTimelineMilestone`, `PactTimelineCache`, `PactTimelineService`, `PactTimelinePage`; note `pact_timeline_enabled` kill-switch

---

## [0.44.4] — 2026-06-21 (HAB-125, PR #165)

### Meta — HAB-125 debrief: scenario stubs, feature toggle gate, rework checkpoint

- [meta] `skills/verify/draft-scenarios/SKILL.md`: step 5 now writes `// TODO:` comment stubs instead of full test code; `implement` fills in driver calls per WU
- [meta] `skills/build/implement/SKILL.md`: step 4 note to replace stubs before writing production code; added rework cycle checkpoint — at cycles 4, 7, 10, … ask Continue / Simplify / Drop and invoke `plan` if scope is reduced
- [meta] `docs/WORKFLOW.md`: brief-first rule for tickets lacking a UX spec; RC kill-switch consideration for new user-facing features; mandatory full review loop in multi-WU WU cycle
- [meta] `skills/design/plan/SKILL.md`: plan must include RC kill-switch flag for new user-facing features

---

## [0.44.3] — 2026-06-21 (PR #164)

### Fixed

- [user] Archived pacts now animate out smoothly when collapsed — previously items disappeared instantly before the size animation ran

---

## [0.44.2] — 2026-06-21 (PR #163)

### Meta — HAB-114 debrief: multi-WU workflow improvements

- [meta] `docs/WORKFLOW.md`: extracted multi-WU rules into dedicated `### 4.1 Multi-WU tickets` subsection (WU0 PR, one-WU-one-branch, WU cycle)
- [meta] `skills/design/plan/resources/plan-template.md`: added `Branch` column to WU table so branch names are pre-named in the plan comment
- [meta] `skills/build/implement/SKILL.md`: step 3 now explicitly enforces one-WU-one-branch and always creates fresh from `origin/main`
- [meta] `skills/manage/debrief/SKILL.md`: added step 5.1 — approved changes are committed and PRed on `feature/HAB-XX-debrief` before posting the Linear comment

---

## [0.44.1] — 2026-06-21 (PR #161)

### Meta — debrief skill, brief rename, shared dialog principles

- [meta] New `/debrief HAB-XX` skill — post-ticket retrospective: structured dialog, proposes workflow/skill/docs improvements, posts summary as a Linear comment
- [meta] Renamed `/describe-feature` → `/brief`; symmetric pair: `/brief` before a ticket, `/debrief` after
- [meta] Extracted `skills/shared/dialog-principles.md` — non-judgmental framing rules shared by both `brief` and `debrief`
- [meta] `/ship` now proposes `/debrief` after reporting the merge

---

## [0.44.0] — 2026-06-21 (HAB-114, PR #160)

### Added — archive pacts

- [user] You can now archive finished or cancelled pacts you no longer want to see. An Archive / Unarchive button on the pact detail screen lets you hide pacts away without deleting them. Archived pacts are listed separately and shown only when you tap the Archived chip or the "Archived pacts (N)" row at the bottom of the list.
- [non-user] HAB-114: `Pact.archived` bool field; `PactMapper` reads/writes column; migration v8 adds `archived` column. `PactListViewModel.toggleArchived()` + sort order: active → unarchived-completed → unarchived-stopped → archived-completed → archived-stopped. Archive chip row animated via `AnimatedSize` + `FadeTransition`; fires `pact_archived` / `pact_unarchived` analytics events with `source: detail_screen`.

---

## [0.43.1] — 2026-06-19 (HAB-122, PR #156)

### Meta — PR comprehensibility improvements

- [meta] HAB-122: WU0 scenarios-only PR convention — plan skill always generates a scenarios-first work unit; each subsequent WU lists which scenarios it makes green
- [meta] HAB-122: TDD micro-cycle commits — red→green→refactor→commit per logical unit; PRs are reviewable commit-by-commit
- [meta] HAB-122: `[test]` CHANGELOG tag for test-only PRs (no production code); enforced by `lint.py`, excluded from Firebase distribution
- [meta] HAB-122: new `run-scenarios` skill and `/run-scenarios` command — pre-ship integration test gate with optional HAB-XX filter
- [meta] HAB-122: `ios`/`android` skills now execute all setup steps; `flutter run` handed off to user via `!` prefix

## [0.43.0] — 2026-06-18 (HAB-115, PR #155)

### Added — editable notes on finished and cancelled pacts

- [user] You can now write or edit a free-form note on any finished or cancelled pact. The note appears in a dedicated Notes section on the pact detail screen, pre-filled with the cancellation reason if one was given. The Save button activates only when you have unsaved changes.
- [non-user] HAB-115: `PactNoteSection` shared StatefulWidget with platform-split slots; saves to existing `stop_reason` column — no schema change. Fires `pact_note_saved` analytics event.
- [meta] Review loop added to `docs/WORKFLOW.md` (step 15): wait for both review skills + Codecov patch-coverage report + human comments, fix or explain each, re-review on non-trivial changes, loop until explicit approval.
- [meta] `draft-scenarios` skill step 4 now requires presenting name, description, and numbered steps per scenario before writing to disk.

---

## [0.42.35] — 2026-06-17 (HAB-119, PR #154)

### Changed — ship skill: automatic PRODUCT_SPEC + GLOSSARY update

- [meta] HAB-119: `ship` skill now includes a step 5 that reads the merged PR diff and ticket, proposes edits to `docs/PRODUCT_SPEC.md` and `docs/GLOSSARY.md` for user approval, and includes approved changes in the release commit. Step is skipped for `[meta]`/`[ci]`/`[app]`-only CHANGELOG entries.

---

## [0.42.34] — 2026-06-17 (HAB-118, PR #153)

### Added — draft-scenarios skill + auto-review invocation

- [meta] HAB-118: new `draft-scenarios` skill — drafts scenarios (integration tests) from the ticket spec before implementation begins; scenarios start red and give `implement` a clear red-green target. Slash command `/draft-scenarios HAB-XX: <title>`.
- [meta] `implement` skill now auto-invokes `review-architecture` and `audit-code` simultaneously after opening a PR, removing the need for the orchestrator to trigger them manually.
- [meta] `docs/WORKFLOW.md` step 4 updated to invoke `draft-scenarios`; pre-list callout added alongside `analyze` and `plan`.

---

## [0.42.33] — 2026-06-17 (HAB-124)

### Changed — Firebase App Distribution: selective publishing + on-demand cleanup

- [ci] Selective distribution gate: CI now skips Firebase App Distribution when the CHANGELOG entry has no `[user]` or `[app]` bullet; builds still compile and the build number is still bumped (tagged `version-*-none`).
- [ci] New `cleanup-firebase-builds` workflow (manual `workflow_dispatch`): deletes all Firebase builds except the most recent N (default 10, configurable) on both platforms.
- [ci] `scripts/changelog/distribute.py`: new script that determines the `should_distribute` output used by `resolve-version`.
- [ci] `scripts/changelog/lint.py`: extended with `[app]`, `[meta]`, `[ci]` classification tags; fails on unknown `[xxx]` tags.
- [meta] `docs/VERSIONING.md` and `docs/WORKFLOW.md` updated with the new four-tag taxonomy and pipeline diagram.

---

## [0.42.32] — 2026-06-17 (HAB-117, PR #151)

### Added — describe-feature skill

- [user-none]
- [non-user] HAB-117: new `describe-feature` skill — iterative product dialog that validates a rough idea against the spec and glossary, then creates a scoped Linear ticket. Slash command `/describe-feature`. `summarize` updated to offer "describe something new" at session start.

---

## [0.42.31] — 2026-06-17 (HAB-121, PR #150)

### Changed — Developer workflow docs

- [user-none]
- [non-user] HAB-121: extracted Workflow section from AGENTS.md into docs/WORKFLOW.md; imported via @docs/WORKFLOW.md reference.

---

## [0.42.30] — 2026-06-16 (HAB-113, PR #149)

### Fixed — Dashboard bottom sheet drag behaviour

- [user] Flicking the pact panel upward now reliably opens it fully instead of stopping halfway.
- [non-user] HAB-113: store `_computedMaxSize` alongside `_computedMinSize`; extract `pactsPickSnapTarget` so fast-up velocity targets `maxSize` (fully expanded) rather than the hardcoded 0.55 semi-expanded constant.

---

## [0.42.29] — 2026-06-16

### Improved — Dashboard bottom sheet UX

- [user] Your pact counts (active, done, cancelled) now stay visible as you scroll through the list.
- [non-user] Panel max height computed dynamically so the top edge contacts the calendar/content separator; shadow falls on the calendar.
- [non-user] Sticky header separated from list by a divider that lands at the collapsed sheet bottom edge; header has a subtle drop-shadow for visual hierarchy.
- [non-user] Pact list is independently scrollable below the fixed header; dragging from the handle area works correctly on both platforms.
- [non-user] `NotificationListener` blocks `ScrollNotification` from reaching the `Scaffold` to prevent AppBar elevation-tint changes on Android.

---

## [0.42.28] — 2026-06-14 (HAB-110)

### Added — README badges and Codecov coverage

- [user-none]
- [non-user] CI: `flutter test --coverage` + `codecov/codecov-action@v4` upload in the test job
- [non-user] README.md: CI status, coverage, platform, Flutter, and version badges
- [non-user] `docs/VERSIONING.md`: `CODECOV_TOKEN` secret documented

---

## [0.42.27] — 2026-06-14 (HAB-108)

### Added — Licensing research

- [user-none]
- [non-user] `docs/LICENSING.md`: WU1–WU3 research — licence type primer, MIT recommendation, full dependency compatibility audit (all deps are MIT/BSD/Apache-2.0); WU4 pending licence selection

---

## [0.42.26] — 2026-06-14 (PR #141 merged)

### Added — Firebase Remote Config feature toggles (HAB-107)

- [user-none]
- [non-user] `FeatureFlags` value object + `featureFlagsProvider`; reads `language_selection_enabled` and `network_sync_enabled` from RC
- [non-user] `language_selection_enabled` (default `true`): hides language-picker on dashboard and onboarding carousel when `false`
- [non-user] `network_sync_enabled` (default `true`): all `FirestoreSyncService` methods no-op when `false`; sync status button and Sign in with Google hidden; dirty writes preserved for replay
- [non-user] Debug RC overrides screen split into "FEATURE TOGGLES" and "A/B TESTS" sections; overrides take effect immediately without navigation
- [non-user] `docs/FEATURE_TOGGLES.md` added as flag catalogue; `docs/ARCHITECTURE.md` and `docs/PRODUCT_SPEC.md` updated

---

## [0.42.25] — 2026-06-11 (HAB-101)

### Changed — skill_router domain-driven refactor

- [user-none]
- [non-user] Reorganised `scripts/` into `skill_router/` (core, llm, agentic, providers subpackages) and `changelog/`
- [non-user] Introduced `ToolProvider`/`PMToolProvider`/`VCSToolProvider`/`FilesToolProvider` protocols; replaced string-prefix dispatch with `ProviderRegistry`
- [non-user] Moved `LINEAR_PROJECT_ID` and other constants from hardcoded `constants.py` into domain submodules; `skill_router.toml` now holds project-specific config
- [non-user] Split `__main__.py` into thin shim + testable `app.py`; entry point is now `python3 scripts/skill_router` (no `.py`)
- [non-user] Co-located tests under each module's `tests/` subdir; added GitHub/Files provider coverage (79 tests total, up from 62)
- [non-user] Updated CI test discovery command, all skill stubs, and docs references

---

## [0.42.24] — 2026-06-09 (PR #138 merged)

### Changed — tests audit: tearDown fixes, ShowupDateUtils coverage, stop-pact flow (HAB-99)

- [user-none]
- [non-user] Added `addTearDown(container.dispose)` at each call site in 5 test files that leaked `ProviderContainer`
- [non-user] Added `showup_date_utils_test.dart` covering `startOfDay`/`endOfDay` including month-end, year-end, and leap-year boundaries
- [non-user] Added `stop_pact_flow_test.dart`: integration test that stops a pact via pact detail and asserts status + notification cancellation (HAB-100 regression guard)

---

## [0.42.23] — 2026-06-09 (PR #137 merged)

### Changed — debug menu consolidated, section order established (HAB-104)

- [user-none]
- [non-user] Removed bell icon from dashboard nav bar (debug/profile builds); test notification moved to debug menu top
- [non-user] Debug menu section order: Fire test notification → Seed data → RC overrides
- [non-user] Added nullable `buildTopSection` function slot to `RemoteConfigOverridesScrollView`; scroll view reordered (seed before RC entries)

---

## [0.42.22] — 2026-06-09 (PR #136 merged)

### Changed — Flutter UI audit WU6: debug RC overrides extraction (HAB-98)

- [user-none]
- [non-user] Added `RcEntryEditState` sealed class (`AllowedValues` / `IntRange` / `FreeText`) with `computeSaveValue()`; eliminates duplicated `initState`/`dispose` logic from iOS and Android edit dialogs
- [non-user] Added `SeedSection` with `SeedSectionSlots` for platform-agnostic seed-data rendering; owns `seed-local-button`, `seed-remote-button`, `seed-status-text` keys
- [non-user] Added `RemoteConfigOverridesScrollView` with `RemoteConfigOverridesSlots`; both platform pages now contain only Scaffold chrome and slot definitions
- [non-user] 37 new tests across 3 generic test files; 1708 total tests green

---

## [0.42.21] — 2026-06-09 (PR #135 merged)

### Fixed — stale skill names in implement report-back (follow-up to PR #134)

- [user-none]
- [non-user] `implement/SKILL.md` step 15 now references `review-architecture` and `audit-code` (was `review`/`audit`)

---

## [0.42.20] — 2026-06-08 (PR #134 merged)

### Changed — skill-creator skill + skill refactor to lean SKILL.md + resources (HAB-103)

- [user-none]
- [non-user] Added `/skill-creator` slash command (guided new-skill creation and existing-skill refactor)
- [non-user] Renamed `/review` → `/review-architecture`, `/audit` → `/audit-code`; both default to latest merged PR when called with no argument
- [non-user] Extracted reference material from 8 skills into `resources/` sibling files; SKILL.md files now reference them via `@path`

---

## [0.42.19] — 2026-06-08 (PR #133 merged)

### Changed — Flutter UI audit WU5: dashboard + onboarding extraction (HAB-98)

- [user-none]
- [non-user] Added `DashboardBody` with `buildShowupTile` + `buildNoPactsCta` slots; collapsed `_DashboardContent`, `_CalendarStrip`, `_ShowupList` duplication across both platform pages
- [non-user] Added `DashboardActionDescriptor` / `buildDashboardActions` consolidating `kDebugMode` guards; `onDashboardRcOverridesClosed` deduplicates the reload callback
- [non-user] Added `OnboardingSignInController.signIn` extracting the byte-identical `_onSignIn` async block; platform carousels collapsed from `ConsumerStatefulWidget` to `ConsumerWidget` shells
- [non-user] Added `OnboardingCarouselScaffold` owning `PageController` lifecycle and `ref.listen` animation hook
- [non-user] Fixed fire-and-forget `unawaited()` on sign-in button; now properly awaited
- [non-user] 27 new tests across 4 generic test files; 1671 total tests green

---

## [0.42.18] — 2026-06-08 (PR #132 merged)

### Changed — Flutter UI audit WU4: showup detail extraction (HAB-98)

- [user-none]
- [non-user] Added `ShowupDetailContent` StatefulWidget owning `TextEditingController` lifecycle; accepts `ShowupDetailSlots` record (`buildActionButtons`, `buildNoteField`, `buildSaveButton`, `buildErrorContainer`)
- [non-user] Collapsed `showup_detail_page_ios/android` to `StatelessWidget` Scaffold shells; `ShowupDetailContent` renders common layout using `StatusBadge`, `SectionHeader`, `DateRowTile` from WU1
- [non-user] iOS page now uses `ShowupStatusColors.cupertino` replacing the private `_statusColor` switch
- [non-user] 14 new tests in `showup_detail_content_test.dart`; 1644 total tests green

---

## [0.42.17] — 2026-06-07 (PR #131 merged)

### Changed — Flutter UI audit WU3: schedule step extraction (HAB-98)

- [user-none]
- [non-user] Added `ScheduleDetailsState` mixin — owns `dailyTime`, `weekdayEntries`, `monthlyWeekdayEntries`, `monthlyDateEntries`; provides `initScheduleDetails()` bootstrapper and `buildScheduleDetails()` dispatch
- [non-user] `ScheduleDetailsIosState` and `ScheduleDetailsAndroidState` now mix in `ScheduleDetailsState`; platform state reduces to 5 abstract `buildXxxDetails()` overrides + picker chrome
- [non-user] Mode-picker tile rows in both schedule steps replaced with `OptionTile` (WU1 generic)
- [non-user] 11 new tests in `schedule_details_state_test.dart`

---

## [0.42.16] — 2026-06-07 (PR #130 merged)

### Changed — Flutter UI audit WU2: wizard scaffolding generics (HAB-98)

- [user-none]
- [non-user] Added 5 generic widgets: `WizardStyle`, `WizardStepIndicator`, `WizardPageScaffold`, `HabitNameStep`, `TappableSummaryRow`
- [non-user] Collapsed `pact_creation_page` and `pact_edit_page` (iOS + Android) to navbar/AppBar shell — `PageController`, `FocusNode`, animation guard now in `WizardPageScaffold`
- [non-user] `HabitNameStep` owns controller lifecycle; platform wrappers provide field + warning via callbacks
- [non-user] `TappableSummaryRow` replaces 4 private `_TappableSummaryRow` duplicates; `useInkWell` flag restores Material ripple on Android
- [non-user] 5 new test files; 286 pact UI tests green

---

## [0.42.15] — 2026-06-07 (PR #129 merged)

### Changed — Flutter UI audit WU1: shared UI primitives (HAB-98)

- [user-none]
- [non-user] Added 7 generic widgets/helpers: `PactStatusColors`, `SectionHeader`, `StatusBadge`, `DateRowTile`, `OptionTile`, `OverrideBadge`, `RestartRequiredBanner`
- [non-user] Adopted in `pact_detail_page`, `pact_duration_step`, `reminder_step`, `remote_config_overrides_page` — ~200 LOC of byte-identical private classes removed
- [non-user] 7 new widget/unit tests in `test/slices/{pact,debug}/ui/generic/`

---

## [0.42.14] — 2026-06-07

### Changed — Flutter codebase audit WU6: cross-slice inversion (HAB-97)

- [user-none]
- [non-user] Added `dashboardRefreshSignalProvider` (`StateProvider<int>`) in `slices/dashboard/ui/generic/dashboard_refresh_signal.dart`
- [non-user] `DashboardViewModel.build()` listens to the signal and calls `load()` + invalidates `hasActivePactsProvider`
- [non-user] `pact_creation_screen.dart` and `pacts_summary_bar.dart` now post to the signal instead of importing `dashboardViewModelProvider` directly — cross-slice dependency removed
- [non-user] Cross-slice signals pattern documented in `docs/ARCHITECTURE.md`
- [non-user] 3 new unit tests covering `dashboardRefreshSignalProvider` and signal → VM reload integration

---

## [0.42.13] — 2026-06-07

### Changed — Flutter codebase audit WU5: strict layer rule enforcement (HAB-97)

- [user-none]
- [non-user] Introduced `ShowupService`, `DashboardQueryService`, `PactListQueryService` so UI view models never import repositories directly
- [non-user] `hasActivePactsProvider` now delegates to `PactListQueryService`
- [non-user] 18 new unit tests covering all three services
- [non-user] Strict layer rule documented in `docs/ARCHITECTURE.md`

---

## [0.42.12] — 2026-06-07

### Changed — Flutter codebase audit WU4: comment hygiene — UI + theme + navigation + l10n (HAB-97)

- [user-none]
- [non-user] 1062 net lines removed across 25 files in `lib/slices/*/ui/`, `lib/theme/`, `lib/navigation/`, `lib/l10n/date_formatters.dart`
- [non-user] Removed narration comments, boilerplate field/class docs, divider lines; kept invariants, PII rules, platform quirks, and non-obvious WHY notes
- [non-user] Added `docs/CODE_STYLE.md` (formatting, linting, comment hygiene rules); updated `AGENTS.md` and `skills/build/implement/SKILL.md` to reference it
- [non-user] Added comment hygiene check to `skills/verify/review/SKILL.md`

---

## [0.42.11] — 2026-06-07 (PR #125 merged)

### Changed — Flutter codebase audit WU3: comment hygiene — domain + application (HAB-97)

- [user-none]
- [non-user] ~50% reduction in `//` lines, ~30% reduction in `///` lines across `lib/domain/` and `lib/slices/*/application/`
- [non-user] Removed narration comments and boilerplate field docs; kept invariants, contracts, and non-obvious WHY notes

---

## [0.42.10] — 2026-06-07 (PR #124 merged)

### Changed — Flutter codebase audit WU2: comment hygiene — infrastructure + main.dart (HAB-97)

- [user-none]
- [non-user] ~50% reduction in `//` lines, ~30% reduction in `///` lines across `lib/main.dart` and `lib/infrastructure/`
- [non-user] Removed narration comments and boilerplate provider docs; kept invariants, no-throw contracts, and non-obvious WHY notes

---

## [0.42.9] — 2026-06-07 (PR #123 merged)

### Changed — Flutter codebase audit WU1: housekeeping (HAB-97)

- [user-none]
- [non-user] Delete stale `lib/features/pact/` directory
- [non-user] Resolve `TODO(HAB-11)` in in-memory repos — convert to "why" note referencing HAB-99
- [non-user] Confirm `first_launch_auth_fix.dart` still needed

---

## [0.42.8] — 2026-06-05 (PR #122 merged)

### Changed — skill_router refactor (HAB-94)

- [user-none]
- [non-user] Split monolithic `scripts/skill_router.py` (~860 lines) into a focused package: `constants`, `frontmatter`, `streaming`, `tool_loop`, `linear_client`, `github_client`, `files_client`, `__main__`
- [non-user] Mirrored test split in `scripts/test_skill_router/`; all 74 tests pass
- [non-user] Stopped auto-loading all doc files into session context (AGENTS.md)

---

## [0.42.7] — 2026-06-04 (PR #121 merged)

### Fixed — Notifications not cancelled after pact stop (HAB-100)

- [user] Stopping a pact now reliably cancels all its pending reminder notifications, even after a cold app restart
- [non-user] `NotificationConstants`: replaced `String.hashCode` (Dart randomises the hash seed per VM process) with FNV-1a 32-bit hash so notification IDs are stable across cold restarts; modulo corrected to `0x40000000` so reminder `[0x0, 0x3FFFFFFF]` and deadline `[0x40000000, 0x7FFFFFFE]` ranges are truly disjoint
- [non-user] `cancelAllRemindersForPact` caller in `PactDetailViewModel.stopPact()` now passes showup IDs so cancellation uses the deterministic hash path instead of the unreliable in-memory registry fallback
- [non-user] All notification ID range bounds written as hex literals for consistency; stability test with hardcoded FNV-1a expected values added
- [non-user] Layer violation fix: `PactDetailViewModel` now reads showups via `pactServiceProvider.getShowupsForPact()` instead of `showupRepositoryProvider` directly
- [non-user] `OnboardingSlideWidget`: spacer wrapped in `Flexible` to prevent column overflow on height-constrained screens (iPhone 17 Pro)

---

## [0.42.6] — 2026-06-02 (PR #120 merged)

### Changed — Documentation audit: GLOSSARY.md, stale-doc removal, skill/experiment fixes (HAB-96)

- [user-none]
- [non-user] Deleted `docs/INJECTIONS.md` (stale since 0.18.1) and `docs/AGENTS.md` (old `.claude/agents/` architecture, superseded by `skills/` in 0.23.2)
- [non-user] New `docs/GLOSSARY.md`: DDD ubiquitous language — canonical domain terms and a term-drift table (session→showup, made→done, cancelled→stopped, weekday→weekly, etc.); registered in AGENTS.md, README.md, and ARCHITECTURE.md
- [non-user] `docs/ARCHITECTURE.md`: fixed stale `reminder/` slice entry and `FirebaseFirestoreClientAdapter` "planned" note; trimmed paragraph-length directory-tree entries to terse one-liners
- [non-user] `README.md`: replaced machine-specific Flutter path with pointer to `CLAUDE.local.md`; fixed stale CI description
- [non-user] `AGENTS.md`: tightened `CLAUDE.local.md` table note (gitignored, contains API keys, never commit)
- [non-user] Skills: `experiment` registry-row format (7 cols, status `pending`); `calibrate` "used by" table added `experiment`+`style`; `audit` `runUpgradeMigrations` method name
- [non-user] Experiments: EXP-002 dates filled; EXP-001/003 + registry start dates harmonised to version strings; EXP-003 stale analytics note removed
- [non-user] `docs/BACKLOG.md`: regenerated with the HAB-95 audit epic and children

---

## [0.42.5] — 2026-05-31 (PR #119 merged)

### Added — FakeFirestoreClient, FaultInjectingFirestoreClient, debug_backend flag, seed data UI, empty state CTA (HAB-90 WU2–WU5)

- [user-none]
- [non-user] `FakeFirestoreClient` + `FakeFirestoreSeedData` (debug/profile only): in-memory `FirestoreClient`; `seed()` (additive), `clear()`, `snapshot()`; defensive copies; lets QA exercise pull/merge path without a live Firestore project
- [non-user] `FaultInjectingFirestoreClient` (debug/profile only): decorator wrapping any `FirestoreClient`; reads `debug_connectivity_state` (perfect/absent/unstable) and `debug_connectivity_stability_percent` from `RemoteConfigService` on every call; injected `Random` for deterministic tests; change via RC overrides screen takes effect immediately without app restart
- [non-user] `debug_backend` RC key (`'real'` / `'local'`): `'local'` wires `LocalAuthService` (auto-signed-in as `localUserId`) + `FaultInjectingFirestoreClient(inner: FakeFirestoreClient)` so QA can test the full sync + connectivity-fault flow without a Firebase project; `'real'` is the default and uses the live Firebase stack unchanged
- [non-user] `LocalAuthService` (debug/profile only): stateful fake `AuthService`; `initialize()` auto-signs-in as `localUserId` (`'local_user_id'`) — no OAuth, no anonymous phase; `signOut()` reverts to anonymous; `linkWithGoogle()` signs back in; no Firebase dependency
- [non-user] `fakeFirestoreClientProvider`: typed `Provider<Object?>` in `app_providers.dart`; avoids importing debug-only `FakeFirestoreClient` in production code; cast to `FakeFirestoreClient?` at debug-only call sites
- [non-user] `RemoteConfigDefaults`: added `debugConnectivityState = 'perfect'`, `debugConnectivityStabilityPercent = 100`, `debugBackend = 'real'`; `allowedValues` for all three keys; new `intRanges` map declaring bounded numeric keys (`debug_connectivity_stability_percent` 0–100, `sync_max_consecutive_failures` 1–20, `onboarding_auto_advance_seconds` 0–60)
- [non-user] `main.dart`: debug/profile builds wire `FaultInjectingFirestoreClient` + `LocalAuthService`/`FakeFirestoreClient` based on `debug_backend` RC key so QA can toggle backend and connectivity faults from the in-app RC overrides screen
- [non-user] `RemoteConfigEntry` gains `intRange: ({int min, int max})?` field + `hasIntRange` getter; populated from `RemoteConfigDefaults.intRanges`
- [non-user] Debug RC overrides UI: bounded numeric keys show a `CupertinoSlider` (iOS) / `Slider` (Android) in the edit dialog instead of a free-text field; saves as integer string; priority order: `allowedValues` → slider → free text; RC debug button added to onboarding carousel nav bar
- [non-user] `DebugSeedDataViewModel` (`AutoDisposeNotifier`, debug/profile only): `seedLocalPacts()` clears SQLite and creates N pacts (N from `max_active_pacts` RC key, clamped ≥ 1) with deterministic IDs and Mon–Fri 08:00 weekly schedule; `seedRemotePacts()` seeds `FakeFirestoreClient` under `localUserId`; `hasFakeBackend` getter gates remote-seed visibility
- [non-user] RC overrides pages (iOS + Android) gain a "SEED DATA" section with "Regenerate local pacts" and "Regenerate remote pacts" buttons; remote button visible only when `debug_backend = local`; busy/done/error status text shown below buttons
- [non-user] Dashboard empty state: when user has no pacts, shows `_NoPactsCta` widget with `l10n.noPactsDescription` text and a primary "Create a pact" button instead of a blank area; FAB (Android) and + button (iOS) are now always visible regardless of pact count
- [non-user] `AppHarness.create()` gains `firestoreClient` param: when provided, `firestoreClientProvider` is overridden instead of `syncServiceProvider`, letting the real `FirestoreSyncService` run end-to-end against `FakeFirestoreClient` or `FaultInjectingFirestoreClient`
- [non-user] 2 new integration tests (`fake_firestore_sync_flow_test.dart`): (1) `pullRemoteChanges` merges `FakeFirestoreClient` data onto dashboard after sign-in; (2) `FaultInjectingFirestoreClient` absent mode prevents remote data from appearing
- [non-user] 13 new `DebugSeedDataViewModel` unit tests; 12 new `LocalAuthService` unit tests; 5 new `RemoteConfigOverridesViewModel` tests; 4 new slider/picker widget tests each on iOS and Android; 2 new `app_container_test.dart` unit tests; 1515 total passing, analyzer clean

## [0.42.4] — 2026-05-29 (PR #118 merged)

### Changed — RC-configurable circuit breaker failure threshold (HAB-90 WU1)

- [user-none]
- [non-user] `RemoteConfigDefaults`: added `syncMaxConsecutiveFailures = 5` constant + `'sync_max_consecutive_failures'` key in `all` map and `allowedValues` map (null = free-value integer, shows text field in debug RC overrides UI)
- [non-user] `SyncCircuitBreaker`: replaced hardcoded `static const _maxConsecutiveFailures = 5` with constructor parameter `{int maxConsecutiveFailures = 5}` — default preserved, all existing call sites unchanged
- [non-user] `syncCircuitBreakerProvider`: reads threshold from `remoteConfigServiceProvider` via `ref.read` at construction time; `> 0` guard falls back to `RemoteConfigDefaults.syncMaxConsecutiveFailures` when RC key is absent/unset (returns 0)
- [non-user] 9 new tests: custom threshold constructor, opens/stays halfOpen at custom threshold, default-5 validation, provider reads RC threshold, provider default, provider fallback-guard (RC returns 0); 1427 total passing, analyzer clean

## [0.42.3] — 2026-05-29 (PR #117 merged)

### Changed — LM Studio tool-calling loop + Linear context pre-injection (HAB-93)

- [user-none]
- [non-user] `skill_router.py`: multi-turn OpenAI tool-calling loop (`chat_completion_with_tools`) — sends `tools` parameter, executes returned `tool_calls`, appends `role: "tool"` results, repeats until final answer or `MAX_TOOL_TURNS = 20`; replaces `needs_session_tools` guard for skills that declare `tools:` in frontmatter
- [non-user] Tool groups supported: `linear` (4 tools: `linear_get_issue`, `linear_list_states`, `linear_update_issue_state`, `linear_create_comment`), `github` (5 tools: `github_get_pr`, `github_list_pr_files`, `github_post_pr_comment`, `github_post_pr_inline_comment`, `github_merge_pr`), `files` (3 tools: `read_file`, `write_file`, `run_bash`)
- [non-user] `read_frontmatter` extended to 6-tuple `(effort, reasoning, needs_session_tools, context, tools, body)` — new `tools` field is a list parsed from `tools: linear,github,files` frontmatter
- [non-user] `_build_tools(groups)` assembles the OpenAI tool-definitions list; `_execute_tool()` dispatches by name to Linear GraphQL, `gh` CLI subprocess, or filesystem/Bash executors
- [non-user] `context: linear` frontmatter handler: pre-fetches open issues and active milestone from Linear GraphQL (`LINEAR_API_KEY` env var) and prepends formatted markdown block before sending to LM Studio — for read-only summarize use-case
- [non-user] `skills/manage/ship/SKILL.md`, `skills/verify/audit/SKILL.md`, `skills/build/implement/SKILL.md`: `needs_session_tools: true` → `tools: linear,github,files` / `tools: github,files` so these skills route to the tool-calling loop on lm-studio-tier models
- [non-user] `skills/manage/summarize/SKILL.md`: `needs_session_tools: true` → `context: linear`; body updated with dual-path instructions (LM Studio: copy pre-fetched block; Claude Code fallback: call `mcp__linear__*`)
- [non-user] 72 unit tests (up from 33); covers `_build_tools`, `_execute_tool` dispatch, multi-turn loop (final answer, tool call+dispatch, max-turns, network error), and all new `main()` paths

## [0.42.2] — 2026-05-28 (PR #116 merged)

### Changed — LM Studio routing script + session-tool guard (HAB-91 WU2)

- [user-none]
- [non-user] `scripts/skill_router.py` — new script routing lm-studio-tier skills to LM Studio's local OpenAI-compatible API; exits non-zero so the stub falls back to Claude Code on failure
- [non-user] `scripts/test_skill_router.py` — 33 unit tests covering all exit-code paths; run via `python3 scripts/test_skill_router.py`; hooked into CI `test` job
- [non-user] `needs_session_tools: true` frontmatter flag added to 7 skill files (summarize, ship, implement, audit, style, ios, android); script exits 2 immediately so these skills always fall back to Claude Code where MCP and Bash tools are available
- [non-user] 7 lm-studio command stubs updated from TODO passthrough to script-routing format with fallback instructions; all stubs changed from `python` to `python3`
- [non-user] `skills/manage/ship/SKILL.md` step 1 gains a multi-WU precondition: if the issue has pending ⏳/🔄 WU items, ship moves to In Progress and adds a comment instead of closing
- [non-user] `skills/configure/calibrate/SKILL.md` step 5a fully defines the lm-studio stub format and documents `needs_session_tools` behaviour
- [non-user] HAB-93 created: research ticket for enabling proper tool-calling in LM Studio-routed skills

## [0.42.1] — 2026-05-28 (PR #115 merged)

### Changed — Skill tier routing: Claude-tier skills dispatched to correct model (HAB-91 WU1)

- [user-none]
- [non-user] `plan` and `calibrate` command stubs updated to spawn an `Agent(model: "opus")` subagent — these are THOROUGH+ARCHITECTURAL skills that benefit from the most capable model
- [non-user] `analyze`, `experiment`, and `review` stubs remain local execution (FOCUSED+ARCHITECTURAL = sonnet = default session model; spawning adds overhead with no benefit)
- [non-user] `docs/MODEL_TIERS.md` active mapping gains a `Claude Code alias` column (`opus`/`sonnet`/`lm-studio`) and lists models in a table with access method (Anthropic API vs LM Studio local)
- [non-user] `qwen/qwen3-8b (MLX, 4-bit)` added to available models; replaces `claude-haiku-4-5` for RAPID+TACTICAL and RAPID+MECHANICAL tiers
- [non-user] `calibrate` SKILL.md step 5a added: routing rule (spawn up / run locally / route to lm-studio) and stub maintenance instructions for future recalibrations
- [non-user] TODO markers added to 7 lm-studio-tier stubs pending WU2 (LM Studio routing script)

---

## [0.42.0] — 2026-05-27 (PR #114 merged)

### Added — Debug Remote Config overrides UI (HAB-89 WU2)

- [user-none]
- [non-user] `RemoteConfigOverridesPageIos` and `RemoteConfigOverridesPageAndroid` — debug/profile-only screens listing all RC keys with effective values and OVERRIDE/DEFAULT badges; entry point gated on `kDebugMode || kProfileMode` via a wrench/tune icon in the dashboard nav bar
- `RemoteConfigOverridesViewModel` (`AutoDisposeNotifier`) — builds `RemoteConfigEntry` list from `RemoteConfigOverrideStore` + `RemoteConfigService`; exposes `setOverride`, `clearOverride`, `clearAllOverrides`
- `RemoteConfigDefaults.allowedValues` map — declares constrained keys (`notification_text_variant`, `post_deadline_notification_behavior`, `exp_003_commitment_confirmation`) so the UI shows a segmented/radio picker instead of a free-text field for those keys
- 32 new tests (11 unit + 11 iOS widget + 10 Android widget); analyzer clean

---

## [0.41.0] — 2026-05-27 (PR #113 merged)

### Added — Debug Remote Config override layer: service layer (HAB-89 WU1)

- [user-none]
- [non-user] `RemoteConfigOverrideStore` abstract interface (`lib/infrastructure/remote_config/contracts/`) — sync reads, async writes; `getOverride(key)` returns `null` when no override is set; `setOverride`/`clearOverride`/`getAllOverrides` round out the API
- [non-user] `NoopRemoteConfigOverrideStore` — const no-op default; wired as `remoteConfigOverrideStoreProvider` in tests and release builds
- [non-user] `SharedPreferencesRemoteConfigOverrideStore` — persists overrides under `rc_override_<key>` prefix; synchronous reads via SharedPreferences in-memory cache; async writes via `prefs.setString`/`prefs.remove`
- [non-user] `OverridableRemoteConfigService` — wraps any inner `RemoteConfigService` + an `RemoteConfigOverrideStore`; checks the store first on every `getInt`/`getBool`/`getString`/`getDouble` call; falls back to the inner service when no override is set or the stored string can't be parsed to the target type
- [non-user] `remoteConfigOverrideStoreProvider` added to `app_providers.dart`; defaults to `NoopRemoteConfigOverrideStore`; overridden in debug/profile builds via `AppContainer.overrides`
- [non-user] `AppContainer.overrides` gains optional `remoteConfigOverrideStore` parameter
- [non-user] `main.dart` debug/profile path: creates `SharedPreferencesRemoteConfigOverrideStore(prefs)` and `OverridableRemoteConfigService(inner: NoopRemoteConfigService(), store: store)`; wires both via `AppContainer.overrides`; release path unchanged (Firebase Remote Config directly)
- [non-user] `docs/ARCHITECTURE.md` updated: `remote_config/` directory tree expanded with the four new files; Remote Config infrastructure paragraph updated to describe the debug override layer
- [non-user] 63 new tests: `noop_remote_config_override_store_test.dart` (5), `shared_preferences_remote_config_override_store_test.dart` (10), `overridable_remote_config_service_test.dart` (15), `app_container_test.dart` +2; `integration_test/remote_config_overrides_flow_test.dart` (6); 1385 tests passing, analyzer clean

---

## [0.40.6] — 2026-05-26 (PR #111 merged)

### Fixed — iOS nav bar turns white on scroll in detail and wizard screens (HAB-88)

- `CupertinoNavigationBar` now keeps the mint surface colour when content scrolls underneath it on pact detail, showup detail, pact creation, and pact edit screens
- Root cause: all four screens set `backgroundColor` on `CupertinoPageScaffold` but not on `CupertinoNavigationBar`; Cupertino fell back to `CupertinoColors.systemBackground` (white) on scroll
- Fix: added `backgroundColor: Theme.of(context).colorScheme.surface` to the `CupertinoNavigationBar` in all four affected files
- 7 new widget tests verify the nav bar and scaffold background colors match the theme surface color

---

## [0.40.5] — 2026-05-25 (PR #110 merged)

### Fixed — Calendar strip selected day resets to today on navigation return (HAB-87)

- Selecting a day other than today in the dashboard calendar strip and then navigating to a showup detail and back no longer resets the selection to today
- `DashboardViewModel._loadInner()` now preserves `selectedDayIndex` when reloading on the same calendar date; it only resets to today on the first load or when the date crosses midnight and `todayIndex` shifts

---

## [0.40.4] — 2026-05-25 (PR #109 merged)

### Fixed — CI builds broken by builtInKotlin migration

- Android: pin `org.jetbrains.kotlin.android version 2.2.20 apply false` in `settings.gradle.kts` — Flutter 3.44's built-in Kotlin defaults to 2.0.0 but Firebase 12.4.1 requires Kotlin 2.2.0; the version declaration overrides the default without re-applying the plugin
- iOS: add `pod repo update` step before `flutter build ios` in CI — macOS runner's CocoaPods specs index was stale, could not resolve `flutter_timezone` 5.0.2

---

## [0.40.3] — 2026-05-25 (PR #108 merged)

### Fixed — Migrate Android build to Flutter built-in Kotlin (HAB-86)

- Set `android.builtInKotlin=true` in `gradle.properties` to opt in to Flutter 3.44's built-in KGP management; removes the duplicate-registration warning that will become a build error in a future Flutter release
- Removed explicit `id("kotlin-android")` from `android/app/build.gradle.kts` and the KGP version declaration from `android/settings.gradle.kts`
- Bumped `flutter_timezone ^3.0.0 → ^5.0.0`; adapted the one call site: `getLocalTimezone()` now returns `TimezoneInfo` — IANA string accessed via `.identifier`
- Package upgrades: firebase_analytics 12.4.1, firebase_remote_config 6.5.1, firebase_auth 6.5.1, firebase_core 4.9.0, google_sign_in_android 7.2.11, cloud_firestore 6.4.1
- iOS Firebase kept on CocoaPods (SPM migration deferred to a separate ticket)

---

## [0.40.2] — 2026-05-25 (PR #107 merged)

### Changed — Stabilise integration tests and migrate to iOS simulator (HAB-76)

- [user-none] Integration test suite made platform-agnostic: `_swipeWizardForward` in `create_pact_flow_test.dart` now tries the iOS PageView key first, falling back to Android — tests run on both platforms without modification; `(Android)` suffix removed from all integration test group names
- [user-none] `waitFor` default timeout increased from 5 s to 10 s; two fixed-time `pump(500 ms)` waits in `showup_to_pact_navigation_flow_test.dart` replaced with `pumpAndSettle()` for deterministic animation settling
- [user-none] CI integration test job switched from Android emulator on `ubuntu-latest` to iOS simulator on `macos-latest` (Android emulator consistently hit a disk-space FATAL at AVD creation); job kept but disabled (`if: false`) — integration tests run locally as the pre-merge gate
- [user-none] Workflow updated (AGENTS.md): integration tests authored after plan approval and before implementation; opportunistic changes during implementation require an integration test first; local integration test run required before invoking ship

---

## [0.40.1] — 2026-05-24 (PR #106 merged)

### Fixed — Past showups not generated when app is opened after a long absence (HAB-85)

- [user] When a user reopens the app after an extended absence all showups that fell in the gap between the last generated showup and today are now generated and immediately auto-failed, so pact history and stats accurately reflect the missed period
- `getLatestScheduledAtForPact(pactId)` added to `ShowupRepository` interface and both implementations (`InMemoryShowupRepository`, `SqliteShowupRepository`) — returns the max `scheduledAt` for a pact, or `null` if no showups have been persisted
- Gap-fill pass added to `DashboardViewModel._loadInner()`, running before the existing forward generation: for each active pact it checks the latest persisted showup date, and if there is a gap up to yesterday it generates the missing showups via `ShowupGenerationService` and marks each one failed immediately; `ShowupAutoFailedEvent` fires per gap showup; reminders are cancelled; per-showup errors are isolated so one bad row cannot block the rest
- The pass is idempotent: once the gap is filled `getLatestScheduledAtForPact` returns a date ≥ today and no additional work is done on subsequent loads
- 4 new SQLite tests and 5 new `DashboardViewModel` gap-fill tests; 1342 tests passing, analyzer clean

---

## [0.40.0] — 2026-05-24 (PR #105 merged)

### Added — Card-based schedule editor in pact creation and editing (HAB-80)

- [user] The schedule step in the pact creation and editing wizards now uses a clean card-based layout — add weekly or monthly time slots as individual cards, with a time picker per card and a toggle for each weekday.
- [user] New pacts default to a Monday–Friday 08:00 weekly slot so most users can tap straight through the schedule step without any changes.
- `SlotSchedule` sealed class (`WeeklySlot`, `MonthlySlot`) added to the domain; `PactBuilder.fromPact()` migrates legacy `DailySchedule`/`WeeklySchedule`/`MonthlyByWeekdaySchedule`/`MonthlyByDateSchedule` to `SlotSchedule` transparently on edit
- `SlotScheduleEditor` shared widget (`generic/`) handles slot add/remove, weekday toggling, and time-picker callbacks; injected `showTimePicker` keeps iOS/Android pickers platform-native
- `ScheduleCodec` extended to encode and decode `SlotSchedule` round-trips
- `ShowupGenerator` extended to generate showups from `SlotSchedule`
- `scheduleCardWeekly` / `scheduleCardMonthly` l10n keys added in EN/FR/DE/RU
- 7 integration tests, 15 `SlotScheduleEditor` widget tests, and 223 `ShowupGenerator` slot tests added; 1333 tests passing, analyzer clean

---

## [0.39.1] — 2026-05-23 (PR #104 merged)

### Fixed — First showup appears already failed when wizard takes too long (HAB-84)

- [user] Creating a pact now correctly skips the first showup's slot when you finish the wizard after the slot's window has already closed — no more instant auto-fail on the first showup.
- `pactCreationSubmitNowProvider` introduced alongside `pactCreationTodayProvider`; `submit()` now reads the clock fresh at submit time instead of reusing the stale wizard-open timestamp, preventing a showup from being generated after its window has already closed.
- Filter predicate upgraded from `scheduledAt >= now` to `scheduledAt + duration > now` across `PactService.createPactFromBuilder`, `ShowupGenerator.countTotal`, and `ShowupGenerationService.ensureShowupsExist`; the window-end comparison correctly keeps a slot that is still open at submit time (e.g. submitted at 9:05 inside a 9:00–9:30 window).

## [0.39.0] — 2026-05-23 (PR #103 merged)

### Changed — Wizard UX: auto-keyboard on habit-name step; tappable step indicator (HAB-82)

- [user] The keyboard now opens automatically when the creation or edit wizard starts on the habit-name step, and closes when swiping to any other page
- [user] Tapping a segment in the step indicator bar now jumps directly to that step in all four wizards (creation iOS/Android, edit iOS/Android)
- `HabitNameStep{Ios,Android}` gain an optional `FocusNode` param and `autofocus: true`; page containers manage focus via `_handlePageChanged` (request on page 0, unfocus otherwise)
- `GestureDetector(behavior: HitTestBehavior.opaque)` wraps each step indicator segment, wired to `onJumpToStep`; missing widget keys added to Android creation segments for test parity
- `_isProgrammaticAnimation` flag suppresses intermediate `onPageChanged` callbacks during `animateToPage` jumps, preventing the step indicator from flashing through intermediate pages
- Guard in `didUpdateWidget`: skip `animateToPage` when `isScrollingNotifier.value` is true to avoid fighting a user swipe mid-scroll (fixed Flow 1 integration test regression on Android CI)
- 10 new widget tests; fixed no-op cascade in summary-row test and added missing assertion; 1257 tests passing, analyzer clean

---

## [0.38.0] — 2026-05-23 (PR #101 merged)

### Added — Edit pact: update habit name and reminder after creation

- [user] Active pacts now have an edit button — tap it to rename the habit or change the reminder
- `PactEditScreen` (ConsumerStatefulWidget) — orchestrates the edit wizard; calls `vm.load()` on mount, logs `PactEditAnalyticsScreen` screen view, fires `PactWizardAbandonedEvent(mode: 'editing')` via `PopScope` when dismissed without saving, and pops with `true` on successful save so `PactDetailScreen` can refresh
- `PactEditViewModel` (Riverpod `NotifierProviderFamily<_, String>`) — loads the pact into a pre-populated `PactCreationState` via `PactBuilder.fromPact()`; exposes `setHabitName`, `setReminderOffset`, `clearReminderOffset`, `goToPage`, `markSummaryJumped`, and `save()`; `save()` uses `originalPact.copyWith(...)` to preserve all immutable pact fields (schedule, dates, duration, status), reschedules reminders after a successful write, and fires `PactEditSavedEvent`
- `PactEditPageIos` / `PactEditPageAndroid` — 3-page swipeable wizard (habit name → reminder → summary); reuses `HabitNameStep{Ios/Android}` with `showCommitmentWarning: false` and `ReminderStep{Ios/Android}` unchanged; new `_EditSummaryStep{Ios/Android}` shows only habit + reminder rows as tappable jump-back rows; `_EditStepIndicator` with 3 segments using `kEditWizardPageCount`; `_TappableSummaryRow` fires `PactWizardStepJumpedEvent(mode: 'editing')` via `_onJumpToStep` in the screen
- `kEditSteps` / `kEditWizardPageCount` constants exported from `pact_edit_view_model.dart`; `_editPageIndex()` helper maps `PactWizardStep` enum values to the edit PageView's 0-based index
- `PactDetailPageIos` / `PactDetailPageAndroid` updated: pencil / edit icon button in the nav bar / AppBar shown only when pact is active; showup duration and reminder rows added to the Timeline section as `_LabelValueRow` widgets
- `PactDetailScreen` wires `_onEditPact()` — pushes `PactEditScreen`, reloads detail VM on `pop(true)`
- `PactBuilder.fromPact(Pact)` factory populates all wizard fields from an existing pact
- Analytics: `PactEditSavedEvent` (properties: `has_reminder: bool`) and `PactEditAnalyticsScreen` (screen_name: `pact_edit`) added; `PactWizardAbandonedEvent` and `PactWizardStepJumpedEvent` reused with `mode: 'editing'`
- l10n: `pactEditTitle`, `saveChanges`, `pactEditSaveError` added across EN/FR/DE/RU
- 30 new `PactEditViewModel` unit tests covering all state transitions, save paths, analytics calls, and reminder scheduling; 1239 tests passing, analyzer clean

---

## [0.37.1] — 2026-05-22 (PR #102 merged)

### Fixed — Release notes no longer leak implementation details (HAB-83)

- [user-none]
- `skills/manage/ship/SKILL.md` step 2 now requires every CHANGELOG entry to carry `[user] <plain English description>` or `[user-none]`; entries missing both markers are flagged as a commit error
- `AGENTS.md` step 11 adds a release note tagging reminder pointing to the ship skill convention
- Retroactively tagged five CHANGELOG entries (0.34.3–0.37.0) that were missing markers and leaking implementation details into Firebase App Distribution release notes

---

## [0.37.0] — 2026-05-21 (PR #100 merged)

### Added — Swipeable PageView wizard UI with EXP-003 commitment dialog (HAB-82 WU2)

- [user] Pact creation wizard is now swipe-based — swipe left to advance between steps, right to go back
- [user] A step indicator shows your progress through the wizard at a glance
- [user] The final summary page lets you tap any section to jump back and edit it
- Six-page `PageView` wizard on both iOS and Android replacing the old Next/Back button flow; users swipe horizontally between steps
- Step indicator bar: current step = full primary colour, past steps = primary at 30% alpha, upcoming = surface-container grey
- `SummaryStepIos` / `SummaryStepAndroid`: tappable rows jump back to the relevant step via `PactWizardStepJumpedEvent` + `PageController.animateToPage`; Create Pact button pinned inside the summary page so it slides in with the page
- `CommitmentDialogContent` implements all three EXP-003 variants: `button` (single accept), `checkbox` (must tick before enabling accept), `retype` (must type habit name exactly, case-insensitive)
- `HabitNameStepIos` / `HabitNameStepAndroid`: dedicated first step widgets with `TextEditingController` managed in `StatefulWidget` (create in `initState`, sync in `didUpdateWidget`, dispose in `dispose`) — eliminates controller leak from all-pages-mounted `PageView`
- `PopScope` on `PactCreationScreen` fires `PactWizardAbandonedEvent` on back-navigation, guarded by `_pactCreated` flag so it never fires after a successful submission
- `if (!mounted) return` guard added to `_onSubmit` after `await showDialog` to prevent `ref` access on a disposed widget
- Swipe hint "Swipe to move between steps" shown on every wizard page including summary; Create Pact button appears above the hint on the summary page
- Create Pact button disabled until `PactBuilder.isComplete` (non-empty habit name, valid date range, showup duration set, schedule set)
- `wizardSwipeHint`, `wizardSummaryTitle`, `createPactConfirm`, `commitmentAccept` l10n keys added across EN/FR/DE/RU
- Integration test uses `flingFrom(pageView.top + 40px)` to avoid the `Slider` on the showup-duration page intercepting horizontal gestures
- 1209 tests passing, analyzer clean

---

## [0.36.0] — 2026-05-21 (PR #99 merged)

### Added — Application layer for swipeable modular wizard (HAB-82 WU1)

- [user-none]
- `PactWizardStep` enum replaces `PactCreationStep` with 6 values (`habitName`, `duration`, `showupDuration`, `schedule`, `reminder`, `summary`); each value's `int` matches the future `PageView` page index for zero-cost int↔enum conversion
- `canAdvanceFromStep` removed — no per-step gating in the swipeable wizard; the Summary page Create button gates submission
- `PactCreationViewModel.nextStep()`/`previousStep()` replaced by `goToPage(int page)` (clamped, logs breadcrumb, preserves the 10-min `showupDuration` default on first visit)
- `markSummaryJumped()` added to VM — idempotent, sets `usedSummaryJump: true` for analytics
- `submit()` gains `required commitmentVariant: String` forwarded to `PactCreatedEvent` (EXP-003)
- `PactCreatedEvent` gains `usedSummaryJump: bool` and `commitmentVariant: String`; 4 new analytics classes: `PactCommitmentDialogDismissedEvent`, `PactWizardStepJumpedEvent`, `PactWizardAbandonedEvent`, `PactWizardSummaryAnalyticsScreen`
- EXP-003 experiment file registered (`exp_003_commitment_confirmation`: `button` / `checkbox` / `retype`)
- Experiment registry gains `pending` status, Start date and End date columns; all 3 experiments set to `pending`
- Platform pages updated with minimal compile fixes and `TODO(WU2)` markers; full UI replacement in WU2
- 1163 tests passing, analyzer clean

---

## [0.35.0] — 2026-05-20 (PR #98 merged)

### Added — Navigate to pact detail from showup detail screen (HAB-81)

- [user] Showup detail screen now has a "View pact details" link that opens the parent pact's detail screen
- Showup detail screen now shows a small **"View pact details ›"** row beneath the habit name that navigates to the parent `PactDetailScreen`; uses `CupertinoPageRoute` on iOS and `MaterialPageRoute` on Android
- When the parent pact has been deleted the link is absent and the habit name shows the localised "(habit deleted)" fallback as plain non-tappable text
- New l10n key `showupViewPactDetails` added across EN/FR/DE/RU
- Full end-to-end integration test covering the complete navigation chain (dashboard → showup detail → pact detail → back → showup detail → back → dashboard) and the deleted-pact guard case
- Integration test platform-agnostic fixes: `create_pact_flow_test`, `language_change_flow_test`, and `sync_on_login_flow_test` replaced Material-only widget finders (`TextField`, `CheckboxListTile`, `SimpleDialog`, `AlertDialog`) with finders that work on both iOS and Android

---

## [0.34.4] — 2026-05-18 (PR #96 merged)

### Fixed — Cold-start blink and dark-mode black background on iOS (HAB-77)

- [user] App opens without a brief blank screen on cold start
- [user] Screens no longer show a black background when dark mode is enabled on iOS
- Write-once SharedPreferences flag (`habit_loop_onboarding_passed`) replaces the async DB pre-fetch approach: read synchronously before the first frame so the carousel/dashboard routing decision is available with no I/O and no `AsyncLoading` state
- `isCarouselPending` spinner removed from `DashboardPageIos` and `DashboardPageAndroid` — no more blank+spinner intermediate frame on cold start
- `OnboardingPreferenceService` interface + `SharedPreferencesOnboardingService` (production) + `NoopOnboardingService` (default) added under `lib/infrastructure/onboarding/`
- `showCarousel` formula simplified: `!onboardingPassed && (isNewUser || isSigningIn)` — flag short-circuits for returning users; `isNewUser` names the concept clearly
- `markOnboardingPassed()` deferred to `addPostFrameCallback` to keep `build()` a pure function of state
- All `CupertinoPageScaffold` widgets (onboarding carousel, pact creation, pact detail, showup detail) now set `backgroundColor: Theme.of(context).colorScheme.surface` — fixes black background in dark mode and white (non-mint) background in light mode on iOS
- 1140 tests passing, analyzer clean

---

## [0.34.3] — 2026-05-18 (PR #95 merged)

### Fixed — iOS nav bar turns white when pacts panel is dragged up (HAB-78)

- [user] Navigation bar no longer turns white when scrolling the pacts panel
- `CupertinoNavigationBar` had no explicit `backgroundColor`; it fell back to the translucent `barBackgroundColor` from `CupertinoThemeData` (system background). When the pacts `DraggableScrollableSheet` is dragged up, its white list-tile content entered the blur zone and the bar appeared white
- Fix: `backgroundColor: Theme.of(context).colorScheme.surface` added to the nav bar — makes it opaque and keeps it mint regardless of what scrolls behind it

---

## [0.34.2] — 2026-05-18 (PR #94 merged)

### Fixed — Dashboard loading blink and 24-hour time picker on iOS

- [user] Dashboard no longer shows a brief nav-bar/spinner flash between the splash screen and the home screen on cold launch
- [user] Time picker in pact creation now shows 24-hour format (e.g. 14:30) on devices set to European locales instead of always showing AM/PM
- `isCarouselPending` flag propagated from `DashboardScreen` to both platform pages; a centered loading spinner is shown while `hasActivePactsProvider` resolves (~10–50 ms), eliminating the blink for both new and returning users
- Removed the incorrect `!state.isLoading` guard from the carousel condition — it was the wrong proxy and caused the scaffold to flash
- `CupertinoDatePicker` in `schedule_step_ios.dart` now passes `use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx)`; display labels already used `TimeOfDay.format(context)` which was already locale-aware

---

## [0.34.1] — 2026-05-17 (PR #93 merged)

### Fixed — Onboarding carousel sign-in and dashboard flash (HAB-75)

- [user] Sign-in button stays visible and shows a loading spinner while Google login is in progress
- [user] Dashboard no longer flashes an empty state on first launch while data is loading
- [user] Onboarding illustration accent dots softened for a cleaner look
- `if (isAnonymous || isSigningIn)` guard prevents the sign-in section from vanishing the moment auth state flips, before the loading flag resets
- `hasActivePactsProvider` polling loop (50 ms interval, 10 s deadline) waits for the dashboard to fully settle before the carousel unmounts
- `valueOrNull ?? false` in `DashboardScreen` replaces the loading-state branch so the carousel renders immediately on cold start without a spinner flash
- 6 new widget tests covering the polling lifecycle on iOS and Android (settles to data, settles to error, still loading at timeout)

### Added — Automated "What's New" release notes in CI

- [user] Release notes in Firebase App Distribution now show human-readable change summaries instead of a raw build number
- `scripts/generate_release_notes.py`: parses `docs/CHANGELOG.md`, extracts entries newer than the last published build, strips HAB-XX/PR/WU references, and truncates to 4 000 chars for Firebase and App Store compatibility
- `[user]` prefix on CHANGELOG bullets selects exactly which lines appear in release notes; lines without the tag are developer-only and skipped
- `resolve-version` CI job generates notes and uploads a `release-notes` artifact (90-day retention) for manual App Store / Play Store submissions
- Both distribute jobs now use `--release-notes-file` instead of a hardcoded build-number string

---

## [0.34.0] — 2026-05-17 (PR #92 merged)

### Added / Fixed — UI polish: SVGs, sign-in spinner, stopped-pact dates, flaky test (HAB-74)

- [user] Onboarding slide 0: milestone dots moved to r≈60 (between outer arc and inner circle); slides 2 and 3 gain matching milestone dots
- [user] Onboarding slide 1: SVG content scaled 1.5× so all four slides use the same r=90 background circle
- [user] Sign-in loading state: tapping "Sign in with Google" replaces the button with a spinner + "Fetching pacts…" and keeps the carousel visible until `linkWithGoogle` + `pullRemoteChanges` + dashboard reload completes; `onboardingSignInLoadingProvider` (`StateProvider<bool>`) drives the state
- [user] `Pact` domain model gains `stoppedAt: DateTime?` mapped from the existing `actual_end_date` column; pact detail timeline now shows both "Stopped [date]" and "Target [date]" for stopped pacts; pacts-panel tile subtitle shows the same pair
- Flaky carousel swipe-right integration test fixed: replaced `pumpAndSettle` with `waitFor` retry
- Integration tests: all carousel/language/create-pact flow tests now pass `initiallyAnonymous: true` to `AppHarness.create()` so they see the carousel after the auth-gated `showCarousel` change
- 1117 tests passing, analyzer clean

---

## [0.33.0] — 2026-05-17 (PR #91 merged)

### Added — Onboarding carousel for zero-pact empty state (HAB-73)

- [user] Four-slide onboarding carousel replaces the plain empty state shown to users with no pacts: "Build Real Habits" → "Make a Pact" → "Never Miss a Showup" → "Watch Yourself Grow"
- [user] Each slide shows an SVG illustration (`assets/onboarding/`), a bold title, and a body paragraph; all copy available in EN/FR/DE/RU
- [user] Auto-advances every N seconds (controlled by Remote Config `onboarding_auto_advance_seconds`, default 10); values < 5 treated as 0 (disabled); manual swipe resets the timer
- `OnboardingViewModel` (`AutoDisposeNotifier<int>`) owns the slide index, timer lifecycle (`Timer.periodic` + `ref.onDispose`), and analytics
- Analytics: `onboarding` screen view on first render; `onboarding_slide_viewed` on every transition (auto/swipe); `onboarding_completed` on first reach of slide 3; `onboarding_create_pact_tapped` and `onboarding_sign_in_tapped` on button taps
- Layout: PageView → page indicator dots → "Create a Pact" primary button (always) → "Sign in with Google" secondary button (anonymous users only) → subtle language-picker button at bottom
- iOS: `CupertinoPageScaffold(navigationBar: null)`; Android: `Scaffold(appBar: null)` — no top bar at all
- [user] Carousel is shown only when the user has zero pacts (`!hasPacts && !state.isLoading`); once pacts exist the carousel is never shown again
- `flutter_svg: ^2.0.0` added as a production dependency
- 1072 tests passing, analyzer clean

---

## [0.32.3] — 2026-05-16 (PR #90 merged)

### Fixed — Local pacts/showups not uploaded to Firestore after Google sign-in (HAB-73)

- [user] Pacts and showups created before signing in with Google are now correctly uploaded when you link your account
- `main.dart` was not passing `pactSyncRepository` and `showupSyncRepository` to `AppContainer.overrides()`, so both providers fell back to their noop defaults whose `getDirtyPacts()` / `getDirtyShowups()` always return empty lists
- `flushDirtyRecords()` and `forceSyncAll()` therefore found zero dirty records in production and uploaded nothing — the bug was masked before HAB-72 because uploads went via direct `uploadPact/uploadShowup` calls; after HAB-72 blocked anonymous uploads, `forceSyncAll()` became the only post-login upload path, exposing the broken wiring
- Fix: pass `pactSyncRepository: pactRepo` and `showupSyncRepository: showupRepo` (both backed by `SqlitePactRepository` / `SqliteShowupRepository`) to `AppContainer.overrides()` so the sync service can read and mark real dirty records
- Two new `app_container_test.dart` unit tests guard against regression: `pactSyncRepositoryProvider` and `showupSyncRepositoryProvider` override is included when provided
- New integration test in `sync_on_login_flow_test.dart` (spy sync repos + `_DirtyCapturingSyncService`) verifies that `forceSyncAll()` reads dirty records after sign-in — would fail if the providers reverted to noop defaults
- 1072 unit tests passing, analyzer clean

---

## [0.32.2] — 2026-05-16 (PR #89 merged)

### Fixed — Google sign-in: user-not-found error, grey icon after first login, and anonymous sync (HAB-72)

- [user] `user-not-found` no longer crashes sign-in: `linkWithGoogleCredential()` now handles `user-not-found` the same as `credential-already-in-use` — falls back to `signInWithCredential()` so the app recovers when a previously-linked Firebase user was deleted from the console
- [user] Sync icon now updates immediately after first-time Google login: `FirebaseAuthClientAdapter.authStateChanges` uses `userChanges()` instead of `authStateChanges()` so the stream re-emits when `linkWithCredential` flips `isAnonymous` to false (same UID, profile-only change)
- Anonymous user data is no longer synced to Firestore: `FirestoreSyncService` guards `uploadPact`, `uploadShowup`, `flushDirtyRecords`, `pullRemoteChanges`, `triggerManualSync`, and `forceSyncAll` against anonymous users; dirty records accumulate in SQLite and are flushed after the user links their Google account
- 1070 tests passing, analyzer clean

---

## [0.32.1] — 2026-05-16 (PR #88 merged)

### Fixed — Fresh install shows user as already logged in on iOS (HAB-71)

- [user] Fresh installs on iOS no longer incorrectly show a previously signed-in state after reinstalling the app
- On iOS, Firebase Auth credentials survive app uninstall/reinstall in the Keychain; a fresh install would find a non-null `currentUser` and skip anonymous sign-in, leaving the dashboard in a synced/Google-linked state with no local data
- `clearStaleKeychainIfFirstLaunch()` added to `lib/infrastructure/auth/data/first_launch_auth_fix.dart`; called from `main.dart` before `authService.initialize()`: writes a dedicated `habit_loop_launched` SharedPreferences key on the very first launch and calls `signOut()` if a stale Firebase user is found
- 6 unit tests in `test/infrastructure/auth/data/first_launch_auth_fix_test.dart`; 2 new integration flow tests in `integration_test/fresh_install_flow_test.dart` (fresh-install signs out stale user → `cloud_off` shown; returning user is unaffected)
- `AppHarness` harness fixed to emit current auth state after `beforePump` callbacks rather than constructor-time values, so flow tests that mutate auth state in `beforePump` are not silently overwritten
- 1062 tests passing, analyzer clean

---

## [0.32.0] — 2026-05-16 (PR #87 merged)

### Added — Full-stack app harness and UI flow tests (HAB-70)

- [user-none]
- `AppHarness` in `integration_test/harness.dart` boots `HabitLoopApp` with in-memory repositories and fake Firebase services (auth, analytics, sync, notifications, remote config); supports `initiallyAnonymous`, `syncServiceFactory`, `beforePump`, and `extraOverrides` parameters for flexible scenario setup
- 5 integration test flows: create-pact wizard (analytics assert), mark-showup-done (analytics assert), language-change to Russian, sync-on-login with empty start (remote pact appears on dashboard), sync-on-login merge (local + remote pacts both visible after sign-in)
- `SyncStatusViewModel.linkWithGoogle()`: `pullRemoteChanges()` is now awaited before reloading the dashboard, closing a race where the dashboard could read empty repos before Firestore data arrived; `forceSyncAll()` remains unawaited (independent of the reload)
- CI `test-android-integration` job runs integration tests on `android-emulator-runner@v2` (API 31, x86_64); integration tests removed from the host-only `test` job
- `integration_test` SDK dev dependency added to `pubspec.yaml`

---

## [0.31.0] — 2026-05-15 (PR #86 merged)

### Added — Full-sync button in sync status dialog (HAB-69)

- [user] "Full sync" action added to the sync status dialog; visible in `synced`, `degraded`, and `suspended` states (user is online and logged in); hidden in `notLinked`, `noInternet`, and `connecting`
- [user] Tapping Full sync marks all local records dirty, flushes them to Firestore, and shows a snackbar on completion: "Sync complete" on full success, or "Sync failed: N records could not be uploaded" on partial failure (plural-aware, all 4 locales)
- `forceSyncAll()` return type changed from `Future<void>` to `Future<ForceSyncResult>` — a new data class with `attempted`, `pactsFailed`, `showupsFailed`, `failed`, and `succeeded` fields
- `SyncStatusViewModel.fullSync()` fires analytics and returns the total failure count for the snackbar callback
- `ScaffoldMessengerState` captured before dialog opens and threaded through `openSyncStatusDialog` so the snackbar fires correctly after the dialog dismisses on both iOS and Android
- Three new analytics events: `full_sync_triggered` (`from_state`), `full_sync_completed` (`from_state`), `full_sync_failed` (`from_state`, `pacts_failed`, `showups_failed`)
- 1056 tests passing, analyzer clean

---

## [0.30.3] — 2026-05-15 (PR #85 merged)

### Fixed — Anonymous pacts not synced after Google login (HAB-68)

- [user] Pacts created before signing in with Google are now correctly synced to your account after login
- Pacts and showups created while anonymous and online were not re-uploaded to Firestore after linking a Google account when the Firebase UID changed (the `credential-already-in-use` recovery path). They had `dirty=0` after the initial anonymous sync, so `flushDirtyRecords()` silently skipped them
- New `SyncService.forceSyncAll()` method marks every local record as dirty (`dirty=1, synced_at=NULL`) then calls `flushDirtyRecords()`, guaranteeing all records are uploaded under the current UID regardless of prior sync state
- `SyncStatusViewModel.linkWithGoogle()` now calls `forceSyncAll()` instead of `flushDirtyRecords()` after a successful sign-in — safe for both the `linkWithCredential` path (UID unchanged, records re-uploaded harmlessly) and the `signInWithCredential` path (UID changed, records now uploaded correctly)
- `PactSyncRepository.markAllPactsDirty()` and `ShowupSyncRepository.markAllShowupsDirty()` added to domain interfaces; implemented by `SqlitePactRepository` / `SqliteShowupRepository` (single `UPDATE … SET dirty=1, synced_at=NULL`) and no-op'd in the noop/fake implementations
- 10 new tests: 3 `SqlitePactRepository.markAllPactsDirty`, 3 `SqliteShowupRepository.markAllShowupsDirty`, 2 `FirestoreSyncService.forceSyncAll`, 1 `NoopSyncService.forceSyncAll`, 1 `SyncStatusViewModel.linkWithGoogle` sync assertion updated; 1049 tests passing, analyzer clean

---

## [0.30.2] — 2026-05-15 (PR #84 merged)

### Fixed — Google sign-in: re-login after sign-out and missing historical data (HAB-67)

- [user] Re-login after sign-out no longer fails with `_TypeError`: `FirebaseAuthClientAdapter.linkWithGoogleCredential()` now checks for a null `currentUser` and falls back to `signInWithCredential` directly (the same recovery path already used for `credential-already-in-use`)
- [user] Historical pacts and showups now appear after signing in with Google: `SyncStatusViewModel.linkWithGoogle()` fires `pullRemoteChanges()` and `flushDirtyRecords()` after a successful sign-in so the user's Firestore data is hydrated immediately; provider refs captured before the `await` to comply with Riverpod's post-dependency-change ref guard

---

## [0.30.1] — 2026-05-15 (PR #83 merged)

### Changed — CI: cache CocoaPods to fix slow iOS build

- [user-none]
- `actions/cache@v4` added for `ios/Pods` keyed on `ios/Podfile.lock` hash in the `build-ios` job; eliminates 25-30 min cold-compile of gRPC-C++ and Abseil (transitive `cloud_firestore` pods) on every macOS runner — cache-hit builds drop to ~5-10 min
- `AGENTS.md` workflow updated: require a pre-merge `git fetch origin && git rebase origin/main` before merging any feature branch

---

## [0.30.0] — 2026-05-14 (PR #82 merged)

### Added — End-to-end Firestore sync (HAB-66, WU7 of HAB-53)

- `FirebaseFirestoreClientAdapter` implemented in `lib/infrastructure/firestore/data/` — wraps `FirebaseFirestore.instance`; no-throw contract on all 6 methods (`getPacts`, `getShowups`, `upsertPact`, `upsertShowup`, `deletePact`, `deleteShowup`); flat `/users/{uid}/pacts/{id}` and `/users/{uid}/showups/{id}` document paths; no SDK types leak through the `FirestoreClient` interface
- Wired in `main.dart` via `AppContainer.overrides(firestoreClient: ...)` — active in all build modes
- `cloud_firestore: ^6.0.0` added as a production dependency
- [user] Pacts and showups now actually sync to Firestore on every local write; `pullRemoteChanges()` on app start hydrates a fresh install from the remote
- 1039 tests passing, analyzer clean

---

## [0.29.3] — 2026-05-14 (PR #81 merged)

### Fixed — Android signing and Google Sign-In OAuth (HAB-65)

- New Android upload keystore generated and registered; CI `build-android` and `distribute-android` jobs restored
- Debug and release SHA-1 fingerprints registered in Firebase Console → Android app
- `google-services.json` re-downloaded with `oauth_client` entries after Google Sign-In was enabled
- [user] `serverClientId` (web OAuth client ID) now passed to `GoogleSignIn.instance.initialize()` — required on Android for `google_sign_in` v7 to include an `idToken` in the authentication response; without it Android sign-in silently produced a null token and failed

---

## [0.29.2] — 2026-05-14 (PR #80 merged)

### Fixed — Google Sign-In error handling on iOS

- [user] `credential-already-in-use`: Google account was already linked to a prior anonymous Firebase UID (e.g. after reinstall). Now falls back to `signInWithCredential` so the user recovers their existing Google-linked account instead of seeing "Could not sign in"
- [user] `_TypeError`: `idToken` was null in some cases, causing a Dart cast failure before reaching Firebase. Added an explicit null guard with a descriptive exception
- [user] `provider-already-linked`: current user already had Google linked — now treated as a success (no-op) instead of an error

---

## [0.29.1] — 2026-05-14 (PR #79 merged)

### Fixed — Google Sign-In URL scheme on iOS

- `$(REVERSED_CLIENT_ID)` in `ios/Runner/Info.plist` had no Xcode build setting or build phase to resolve it — the URL scheme was passed through unexpanded, so the Google OAuth redirect back to the app never fired and sign-in always failed
- [user] Fixed by hardcoding the actual reversed client ID: `com.googleusercontent.apps.935013168355-3jecs4lf3l2rr4g7dktth2as259i0tve`

---

## [0.29.0] — 2026-05-14 (PR #78 merged)

### Added — Sync status UI (HAB-64, WU6 of HAB-53)

- `SyncUiState` enum (6 states, priority order): `noInternet` > `connecting` > `notLinked` > `suspended` > `degraded` > `synced`
- `SyncStatusViewModel` (`AutoDisposeNotifier<SyncUiState>`) in `lib/slices/dashboard/ui/generic/` watches `connectivityProvider`, `authStateChangesProvider`, and `syncCircuitBreakerProvider` to derive the current sync health state; exposes `triggerManualSync()`, `linkWithGoogle()`, `signOut()` actions
- `connectivityProvider` (`StreamProvider<bool>`) declared in `app_providers.dart` using `connectivity_plus`; emits `true` when any non-none interface is active; defaults to `true` while loading (optimistic) so the UI never flashes "no internet" on startup; `ConnectivityResult` is fully encapsulated inside the provider body
- `sync_status_handler.dart` (shared): `syncStatusIconData(SyncUiState)`, `syncStatusIconColor(SyncUiState, BuildContext)`, `openSyncStatusDialog({context, ref, showFn})` — shared orchestration that fires `SyncStatusOpenedEvent` and builds state-appropriate message + action list; `SyncDialogAction` data class; icon colors use `CupertinoColors.systemGreen/Orange/Red/Grey.resolveFrom(context)` for correct dark-mode adaptation on both platforms
- [user] iOS dashboard nav bar gains a `sync-status-button` `CupertinoButton` with color-coded Material icon; tap shows `CupertinoAlertDialog` with state message and platform-native actions
- [user] Android dashboard AppBar gains a `sync-status-button` `IconButton`; tap shows `AlertDialog` with same state message and actions
- [user] Dialog actions by state: `notLinked` → Sign in with Google + Not now; `suspended`/`degraded` → Sync now + Not now; `synced` → Sign out + Not now; `noInternet`/`connecting` → Not now only
- [user] Sign-in failure surfaces a second dialog with a localised error message (`signInWithGoogleFailed`) instead of silently dismissing; `linkWithGoogle()` rethrows `AuthLinkException` after logging analytics so callers can react
- 6 new analytics event classes (`final class`) in `lib/slices/dashboard/analytics/sync_analytics_events.dart`: `SyncStatusOpenedEvent`, `ManualSyncTriggeredEvent`, `SignInWithGoogleTappedEvent`, `SignInWithGoogleSucceededEvent`, `SignInWithGoogleFailedEvent`, `SignOutTappedEvent`
- 12 l10n keys added across EN/FR/DE/RU: `syncStatusTitle`, `syncStatusSynced`, `syncStatusDegraded`, `syncStatusSuspended`, `syncStatusNoInternet`, `syncStatusConnecting`, `syncStatusNotLinked`, `syncNow`, `signInWithGoogle`, `signOut`, `notNow`, `signInWithGoogleFailed`
- `REVERSED_CLIENT_ID` URL scheme registered in `ios/Runner/Info.plist` so the Google OAuth callback correctly returns to the app on iOS release builds
- `connectivity_plus: ^6.1.4` added as production dependency
- 1039 tests passing, analyzer clean

---

## [0.28.0] — 2026-05-14 (PR #77 merged)

### Added — Pull-on-start sync (HAB-63, WU5 of HAB-53)

- [user] Your pacts and showups now sync automatically from the cloud each time you open the app
- `SyncService.pullRemoteChanges()` abstract method added with full no-throw contract and last-writer-wins merge rules documented
- `NoopSyncService.pullRemoteChanges()` no-op implementation
- `FirestoreSyncService.pullRemoteChanges()`: fetches all remote pacts and showups for the current user; merges into local SQLite using last-writer-wins — not-in-local → insert + mark synced; local dirty → keep local; remote `updated_at` > local `synced_at` → overwrite + mark synced; otherwise keep local; gated on CB being fully `closed`; calls `recordFailure()` on any network error; individual record errors isolated (one bad doc never blocks the rest)
- `PactSyncRepository.getPactSyncedAt(String pactId) → Future<DateTime?>` added to interface and implementations: returns `null` when dirty (unsync'd local changes) or record not found, `synced_at` otherwise
- `ShowupSyncRepository.getShowupSyncedAt(String showupId) → Future<DateTime?>` — mirrors `getPactSyncedAt`
- `SqlitePactRepository` and `SqliteShowupRepository` implement both new methods via a single `SELECT dirty, synced_at` query
- `NoopPactSyncRepository` and `NoopShowupSyncRepository` return `null`
- `SyncMapper` extended with `pactFromDocument()`, `showupFromDocument()`, `updatedAtFromDocument()` decoders; `pactToDocument()` and `showupToDocument()` gain optional `updatedAt` param (defaults to `DateTime.now()`)
- `FirestoreSyncService` constructor gains `pactRepository` and `showupRepository` required params; `syncServiceProvider` in `app_providers.dart` wires them in from existing providers
- `pullRemoteChanges()` called fire-and-forget from `main.dart` after `authService.initialize()`
- `FakeSyncService` gains `pullRemoteChangesCount` counter and `pullRemoteChanges()` increment method
- 20 new tests: 4 `getPactSyncedAt` SQLite tests, 4 `getShowupSyncedAt` SQLite tests, 1 `pullRemoteChanges` noop test, 11 `FirestoreSyncService.pullRemoteChanges` tests; 1005 tests passing, analyzer clean (3 pre-existing errors from gitignored `firebase_options.dart`)

---

## [0.27.0] — 2026-05-14 (PR #76 merged)

### Added — Write-through sync service (HAB-62, WU4 of HAB-53)

- [user-none]
- `SyncService` abstract interface (`lib/infrastructure/sync/sync_service.dart`) with no-throw contract: `uploadPact(Pact)`, `uploadShowup(Showup)`, `flushDirtyRecords()`, `triggerManualSync()`; every implementation must swallow exceptions so sync failures can never block the local write path
- `NoopSyncService` — `const` no-op default wired as `syncServiceProvider`
- `SyncMapper` — `abstract final` class with `static pactToDocument()` and `showupToDocument()` helpers; maps domain models to Firestore-ready `Map<String, dynamic>`; excludes SQLite-only columns (`dirty`, `synced_at`, `total_showups`); encodes `PactStatus` and `ShowupStatus` to strings
- `FirestoreSyncService` — production `SyncService` implementation; checks `canRequest` before each Firestore call; calls `markPactSynced`/`markShowupSynced` on success; calls `recordSuccess`/`recordFailure` on the circuit breaker; fires `unawaited(flushDirtyRecords())` when the CB transitions halfOpen→closed to drain records accumulated during the outage; skips all uploads when `userId` is null (signed-out); `flushDirtyRecords()` caps a single pass at 400 items and stops early if the CB goes open mid-flush
- `syncServiceProvider` (`Provider<SyncService>`) declared in `app_providers.dart`; self-composing from existing providers (`firestoreClientProvider`, `authServiceProvider`, `syncCircuitBreakerProvider`, `pactSyncRepositoryProvider`, `showupSyncRepositoryProvider`); no `AppContainer.overrides` change required
- `SyncCircuitBreaker` gains a public `currentState` getter so external callers can read state without subclassing `StateNotifier`
- `PactService.createPact` and `updatePact` fire `unawaited(_syncService.uploadPact/uploadShowup)` after every successful local write
- `PactStatsService.persistStats`, `persistShowupStatus`, and `stopPact` fire `unawaited(_syncService.uploadPact/uploadShowup)` after every successful local write
- `FakeSyncService` test double in `test/infrastructure/sync/` records `uploadedPactIds`, `uploadedShowupIds`, `flushCount`, and `triggerManualSyncCount`
- 33 new tests: 9 `sync_mapper_test`, 4 `noop_sync_service_test`, 14 `firestore_sync_service_test`, 2 `pact_service_test` sync-hook tests, 3 `pact_stats_service_test` sync-hook tests, 1 `app_container_test` smoke test; 970 tests passing, analyzer clean

---

## [0.26.0] — 2026-05-13 (PR #75 merged)

### Added — Circuit breaker sync service (HAB-61, WU3 of HAB-53)

- [user-none]
- `SyncCircuitBreakerState` enum (`closed`, `halfOpen`, `open`) and `SyncCircuitBreaker` (`StateNotifier<SyncCircuitBreakerState>`) in `lib/infrastructure/sync/sync_circuit_breaker.dart`
- State machine: `closed` → `halfOpen` on any Firestore failure; `halfOpen` → `closed` on success or → `open` after 5 consecutive failures; `open` → `halfOpen` only via `triggerManualSync()` (called from WU6 sync-status UI)
- `canRequest` bool gates all WU4/WU5 sync operations — `false` only in `open` state; both `closed` and `halfOpen` allow requests so the app can probe its way back to `closed` after a transient outage
- CB state is in-memory only — always resets to `closed` on app restart, giving the app a clean probe opportunity on each launch without requiring user action after e.g. an airplane-mode session
- `syncCircuitBreakerProvider` (`StateNotifierProvider<SyncCircuitBreaker, SyncCircuitBreakerState>`) declared in `app_providers.dart`; no override needed
- 19 new tests covering the full state machine, failure counter reset, `triggerManualSync`, and provider smoke tests; 937 tests passing, analyzer clean

---

## [0.25.0] — 2026-05-13 (PR #74 merged)

### Added — Firestore schema + client infrastructure (HAB-60, WU2 of HAB-53)

- [user-none]
- SQLite schema bumped to **v2**: `runMigrations` (fresh installs) adds `dirty INTEGER NOT NULL DEFAULT 1` and `synced_at INTEGER` to both `pacts` and `showups` tables; `runUpgradeMigrations(db, 1, 2)` is an `ALTER TABLE` path for existing installations so existing rows are automatically queued for the first sync (default `dirty = 1`); sync state is internal to the repository layer — domain models (`Pact`, `Showup`) remain clean with no sync fields
- `PactSyncRepository` / `ShowupSyncRepository` interfaces added to `lib/domain/` exposing `getDirtyPacts()` / `getDirtyShowups()` and `markPactSynced()` / `markShowupSynced()`; consumed solely by the upcoming WU4 sync service — view models and application services never depend on these interfaces
- `SqlitePactRepository` and `SqliteShowupRepository` now implement both their respective CRUD repository interface and the corresponding sync repository interface; `NoopPactSyncRepository` / `NoopShowupSyncRepository` no-op defaults wired as `pactSyncRepositoryProvider` / `showupSyncRepositoryProvider`
- `FirestoreClient` abstract interface (`lib/infrastructure/firestore/contracts/`) with a strict no-throw contract; flat `/users/{userId}/pacts/{pactId}` and `/users/{userId}/showups/{showupId}` document paths; all data passed as `Map<String, dynamic>` so the interface has no `cloud_firestore` SDK dependency
- `NoopFirestoreClient` — silent no-op used as the default provider in tests and offline scenarios
- `firestoreClientProvider` wired via `AppContainer.overrides()` following the same optional-override pattern as other infrastructure providers
- `PactMapper` and `ShowupMapper` updated: `toRow()` always writes `dirty = 1` and `synced_at = null` so every local write is queued for the next sync pass; `fromRow()` ignores both columns; `toUpdateRow()` always resets `dirty = 1`
- 918 tests passing, analyzer clean

---

## [0.24.0] — 2026-05-13 (PR #69 merged)

### Added — Auth foundation: anonymous sign-in, device ID, Google account linking (HAB-59)

- [user] You can now sign in with Google to back up and restore your pacts across devices
- `firebase_auth ^6.0.0` and `google_sign_in ^7.0.0` added as dependencies; all existing Firebase packages bumped to latest major (`firebase_core ^4`, `firebase_analytics ^12`, `firebase_crashlytics ^5`, `firebase_remote_config ^6`)
- Every install silently signs in anonymously on first launch via `FirebaseAuthService.initialize()` (fire-and-forget after `runApp`); a stable Firebase UID is available from day one without any user action
- `DeviceIdService` / `SharedPreferencesDeviceIdService`: UUID v4 generated once, persisted under `habit_loop_device_id`, prefixes new pact IDs (`{deviceId}-{uuid}`) for global uniqueness across devices
- `AuthService` interface with no-throw contract on `initialize()` / `signOut()`; `linkWithGoogle()` upgrades the anonymous account to a Google-linked account while preserving the UID
- `FirebaseAuthClient` adapter interface isolates all Firebase + Google SDK types; test fakes implement it without importing any Firebase package
- `AuthState` value type (`userId`, `isAnonymous`, `isSignedIn`) with `==`/`hashCode` and constructor assert guarding the impossible `userId==null && !isAnonymous` combination
- Three new Riverpod providers: `authServiceProvider`, `deviceIdServiceProvider`, `authStateChangesProvider` (`StreamProvider<AuthState>`)
- 880 tests passing

---

## [0.23.4] — 2026-05-12 (PR #68 merged)

### Fixed — App no longer hangs on splash screen when offline (HAB-56)

- [user] The app no longer freezes on the launch screen when you have no internet connection
- `FirebaseRemoteConfigService.initialize()` was `await`ing `fetchAndActivate()` with a 1-minute release timeout, blocking `main()` and keeping the splash screen frozen when the device had no internet connection
- Fix: `setDefaults()` (in-code defaults) is still awaited before `initialize()` returns, so feature flags are available on the first frame; `fetchAndActivate()` is now fire-and-forget and completes in the background whenever the network is reachable
- Release `fetchTimeout` reduced from 1 minute to 15 seconds to limit how long an inflight fetch lingers on a poor connection
- 4 new tests verify the offline-first behaviour; 858 tests passing

### Changed — Remove manual In Progress tracking from BACKLOG.md

- `## In Progress` section removed from `docs/BACKLOG.md`; Linear is the single source of truth for what is in progress
- `AGENTS.md` and `skills/manage/ship/SKILL.md` updated to drop references to that section

---

## [0.23.3] — 2026-05-12 (PR #67 merged)

### Fixed — Showup duration label uses locale-specific unit (HAB-57)

- [user] Showup duration now displays in the correct unit for your language (min, Min., мин)
- `_ShowupTile` in both iOS and Android dashboard pages was rendering the showup duration as a hardcoded English `min` suffix regardless of the active locale
- Fix: replaced `'${showup.duration.inMinutes} min'` with `l10n.showupDurationMinutes(showup.duration.inMinutes)`, which already had correct translations for all four locales (`min` en/fr, `Min.` de, `мин` ru)
- 2 new widget tests (iOS + Android) verify the Russian locale renders `мин`

---

## [0.23.2] — 2026-05-12 (PR #66 merged)

### Changed — Migrate to skills-based Claude agent stack (HAB-58)

- [user-none]
- `.claude/agents/*.md` subagent files replaced with `skills/**/SKILL.md` structure; each skill is a self-contained directory with its own frontmatter, instructions, and output style
- `MODEL_TIERS.md` added at the repo root with a tier mapping (Opus / Sonnet / Haiku) so agent files reference a tier name rather than a hard-coded model ID
- `styles/` directory added with communication presets; each style file documents tone, verbosity, and formatting conventions
- `output_style` field added to all skill frontmatters referencing the appropriate style preset
- "When-to-use" guidance added inside each style file so orchestrators can select the correct preset automatically
- No app code, tests, or l10n strings were changed; purely tooling and documentation

---

## [0.23.1] — 2026-05-09 (PR #63 merged)

### Fixed — iOS notification tap navigation (UNUserNotificationCenter delegate)

- [user] Tapping a reminder notification now correctly opens the showup detail screen on iOS
- Root cause: Flutter 3.x removed the automatic `UNUserNotificationCenter.current().delegate = self` assignment from `FlutterAppDelegate`; without it iOS has no delegate to call on notification tap, so `didReceiveNotificationResponse` was never invoked and the app opened on the dashboard instead of the showup detail screen
- Fix: added `UNUserNotificationCenter.current().delegate = self` to `AppDelegate.application:didFinishLaunchingWithOptions:`; `FlutterAppDelegate` implements `UNUserNotificationCenterDelegate` and forwards via `FlutterPluginAppLifeCycleDelegate` to all registered plugin delegates including `FlutterLocalNotificationsPlugin`
- Cold-start tap guard: retry loop polls until the navigator is mounted before pushing the route, with a `_notificationNavigationHandled` guard flag to prevent double-push
- Notification service enabled in all build modes (removed `kReleaseMode` gate) so notification navigation can be tested on debug builds
- Debug bell button added to the dashboard nav bar (debug builds only) to schedule a test notification for immediate manual verification

---

## [0.23.0] — 2026-05-08 (PR #64 merged)

### Added — Time-derived UI states: Planned and Waiting for start (HAB-54)

- New `ShowupUiState` enum (`planned`, `waitingForStart`, `active`, `done`, `failed`) lives in the UI layer only — no domain model changes
- `deriveShowupUiState()` pure function computes the UI state from `now`, `showup.scheduledAt`, `showup.duration`, `showup.status`, and the pact's `reminderOffset`; `reminderFiresAt = scheduledAt - reminderOffset` (null/zero offset collapses "Waiting for start" into "Planned")
- [user] Dashboard calendar strip: "planned" showups keep the existing empty gray circle; "waitingForStart" and "active" showups show a filled amber circle signalling "something is about to happen / happening now"
- [user] Showup detail status chip now shows all 5 derived state labels ("Planned", "Waiting for start", "Pending", "Done", "Failed") using the injectable `showupDetailNowProvider` clock
- `ShowupStatusColors` extended with `waitingForStart` field, `forUiState()` and `overflowForUiState()` factory methods for consistent colour resolution across iOS and Android
- `showupUiStateText()` formatter added to `showup_formatters.dart`
- `deriveUiStates()` helper extracted to `generic/` eliminating iOS/Android duplication in the dashboard calendar strip
- ARB keys added: `showupPlanned`, `showupWaitingForStart` in EN/FR/DE/RU; 852 tests passing, analyzer clean

---

## [0.22.2] — 2026-05-08 (PR #62 merged)

### Fixed — iOS cold-start notification tap navigation

- [user] Tapping a notification when the app is closed now correctly opens the showup detail screen on iOS
- On iOS, `flutter_local_notifications` v9+ calls `onDidReceiveNotificationResponse` during `initialize()` — before `runApp()` has mounted the widget tree — so `_navigatorKey.currentState` was `null` and the navigation was silently dropped, leaving the user on the dashboard instead of the showup detail screen
- Fix: warm-start taps (navigator already mounted) navigate immediately; cold-start taps (navigator is `null`) defer the push via `addPostFrameCallback` so it fires after the first frame when the navigator is guaranteed to be ready
- `_notificationNavigationHandled` flag prevents the `getAppLaunchDetails()` `addPostFrameCallback` path from also pushing a route on the same cold-start (double-navigation guard); the flag resets after the cold-start frame so subsequent warm-start taps are never blocked

---

## [0.22.1] — 2026-05-08 (PR #61 merged)

### Fixed — WAL pragma crash on Android upgrade from v0.19.0

- [user] The app no longer crashes on startup when upgrading from older versions on Android
- `db.execute('PRAGMA journal_mode=WAL')` changed to `db.rawQuery('PRAGMA journal_mode=WAL')` in `HabitLoopDatabase.onConfigure`; on Android, `execSQL()` (which backs sqflite's `execute()`) throws for result-returning statements, causing "Unable to open the app database" for users upgrading from v0.19.0 (the first release without WAL); `rawQuery` does not assert on result rows and the call is wrapped in try/catch so WAL failure is non-fatal
- `earlycrashlytics.recordError(e, st)` added to the broad catch block in `main()` so future database-init failures appear in Crashlytics rather than being silently swallowed
- Misleading `'Failed to open database'` log message corrected

### Added — App version displayed in dashboard nav bar

- `package_info_plus` added as a dependency
- `appVersionProvider` (`FutureProvider<String>`) returns `"vX.Y.Z (buildNumber)"` from the platform package info
- [user] Both iOS (`CupertinoNavigationBar`) and Android (`AppBar`) dashboard nav bars show a small version subtitle under the "Habit Loop" title; 833 tests passing, analyzer clean

---


## [0.22.0] — 2026-05-08 (PR #60 merged)

### Added — Auto-refresh dashboard when date changes at midnight (HAB-22)

- [user] The dashboard now automatically refreshes when the date changes at midnight, so today's showups are always current
- `WidgetsBindingObserver` added to `_DashboardScreenState`; on `AppLifecycleState.resumed`, if the calendar date has changed since the last load, invalidates `todayProvider` and `hasActivePactsProvider` and re-triggers `load()` on both `DashboardViewModel` and `PactListViewModel`, then logs an analytics screen view
- `_lastLoadDate` assigned synchronously before `addObserver` to close a null-window race where a resume event could fire before the field was set
- `_loadInProgress` guard added to `PactListViewModel` to prevent concurrent load executions on rapid resume cycles
- 4 new widget tests using in-place `StateProvider` date mutation to assert the dashboard refreshes only when the date actually changes; 838 tests passing, analyzer clean

---

## [0.21.0] — 2026-05-08 (PR #59 merged)

### Added — Auto-fail past-due pending showups on dashboard load (HAB-21)

- [user] Showups that passed their scheduled time are now automatically marked as failed
- `DashboardViewModel.load()` runs an auto-fail sweep between the lazy showup generation loop and calendar strip construction; the sweep is guarded by a `_autoFailRunning` flag so rapid reloads never run two sweeps concurrently
- Eligibility filter: showups in the visible past window (today-3 through today) that are still `pending`, belong to an active pact, and whose scheduled window has elapsed (`now > scheduledAt + duration`)
- Per qualifying showup: persists `ShowupStatus.failed` via `PactStatsService.persistShowupStatus` (also refreshes the in-memory stats cache), fires `ShowupAutoFailedEvent` (fire-and-forget, analytics failure never blocks the sweep), and cancels the scheduled reminder via `ReminderSchedulingService.cancelRemindersForShowup`
- Per-showup error isolation: a failure on any single showup is caught, logged, and reported to Crashlytics non-fatally; the sweep continues to the next showup so one bad row cannot block others
- `ShowupAutoFailedEvent` doc comment and `docs/ANALYTICS_EVENTS.md` updated to document that the event covers both triggers: dashboard sweep and showup detail screen auto-open
- 7 new auto-fail sweep tests in `test/slices/dashboard/domain/dashboard_view_model_test.dart`: single auto-fail, multi-pact auto-fail, no-op (future window), no-op (done showup), no-op (stopped pact), analytics event fired, reminder cancelled; 831 tests passing, analyzer clean

---

## [0.20.0] — 2026-05-08 (PR #58 merged)

### Added — Notifications and reminders (HAB-13)

- `flutter_local_notifications`, `timezone`, `flutter_timezone` added as dependencies
- `NotificationService` abstract interface (`lib/infrastructure/notifications/contracts/`) with no-throw contract; `FlutterLocalNotificationService` (production) and `NoopNotificationService` (debug/tests)
- `NotificationConstants` shared class for action IDs and notification ID computation (deterministic, collision-free, two disjoint ID ranges for reminder vs deadline notifications)
- `ReminderSchedulingService` orchestrates scheduling: reads EXP-001 (`notification_text_variant`) and EXP-002 (`post_deadline_notification_behavior`) from Remote Config; resolves locale internally via `LocalePreferenceService`; caps iOS to 32 showups per pass (64-slot limit divided by 2 notifications per showup)
- `NotificationTextBuilder` — pure static class building notification text for three EXP-001 variants (`control`, `deadline`, `time_limit`) plus the missed-deadline replacement text
- [user] Reminder notifications scheduled at pact creation, during dashboard lazy-window generation, cancelled on showup done/failed and on pact stop
- [user] "Missed deadline" replacement notification: on iOS always scheduled (auto-dismiss not available); on Android controlled by EXP-002 (`dismiss` = `timeoutAfter` auto-dismiss, `encourage` = replacement notification)
- Notification tap routing: `lib/navigation/notification_navigator.dart` (platform-correct `CupertinoPageRoute` on iOS, `MaterialPageRoute` on Android); cold-start via `addPostFrameCallback` + `getAppLaunchDetails()`; warm-start via `onDidReceiveNotificationResponse`
- [user] "Mark done" actionable notification button (stretch goal): background isolate handler on Android; foreground handler uses Riverpod container for correct cache invalidation; `PactStatsService` updated on foreground mark-done
- WAL journal mode enabled on SQLite database for safe concurrent access from main + background isolates
- Analytics events: `notifications_scheduled`, `notification_opened`, `app_opened_from_notification` (with `cold_start` bool), `showup_marked_done_from_notification`
- EXP-001 (notification text urgency) and EXP-002 (post-deadline Android behavior) registered in `docs/experiments/`
- [user] Stale notification tap shows localised "This showup is no longer available." message instead of a raw error
- 824 tests passing, analyzer clean

---

## [0.19.0] — 2026-05-06 (PR #53 merged)

### Added — In-app language picker UI, analytics, and Russian locale (HAB-40 WU3)

- [user] iOS language picker: `CupertinoActionSheet` launched from the dashboard nav bar globe icon; displays English, French, German, Russian, and "System default" options; selecting a locale writes via `localePreferenceServiceProvider` and updates `localeOverrideProvider` so the UI re-renders immediately
- [user] Android language picker: `AlertDialog` with a `RadioListTile` per locale, launched from a dashboard overflow menu item; same persistence and hot-swap behaviour
- `LanguagePickerViewModel` (`autoDispose` notifier in `slices/settings/application/`) encapsulates the current locale read from `localeOverrideProvider` and a `selectLocale(Locale?)` action that writes to both the preference service and the provider
- `LanguageSelectedEvent` analytics event (snake_case: `language_selected`, property `locale_code: String`) added to `slices/settings/analytics/` and logged on every user selection
- `openLanguagePicker()` shared helper extracted to `slices/settings/ui/generic/` to eliminate duplication between the iOS and Android call sites
- `docs/ANALYTICS_EVENTS.md` updated with `language_selected` event entry
- `docs/ARCHITECTURE.md` updated with `slices/settings/` directory entries and locale infrastructure paragraph
- Tests: `LanguagePickerViewModel` unit tests (selectLocale persists locale and updates provider, selectLocale with null reverts to system), iOS and Android widget tests asserting picker options appear and locale changes propagate
- 720 tests passing, analyzer clean

---

## [0.18.4] — 2026-05-06 (PR #52 merged)

### Added — Locale persistence infrastructure and AppContainer async overrides (HAB-40 WU2)

- [user-none]
- `shared_preferences: ^2.3.0` added as a production dependency for storing locale preference across sessions
- `LocalePreferenceService` abstract interface introduced in `lib/infrastructure/locale/contracts/` with a no-throw contract: `getSavedLocale()`, `saveLocale(Locale)`, `clearLocale()`
- `SharedPreferencesLocaleService` implements the interface — stores locale as a language code string; validates against `AppLocalizations.supportedLocales` on read so stale or invalid codes return `null` gracefully
- `NoopLocalePreferenceService` returns `null` and no-ops on writes; used as the safe default in tests
- `localePreferenceServiceProvider` and `localeOverrideProvider` (`StateProvider<Locale?>`, `null` = follow system) added to `app_providers.dart`
- `AppContainer.overrides()` extended with optional `localePreferenceService` and `initialLocale` parameters; locale loading moved inside `AppContainer.overrides` so `main.dart` passes the `SharedPreferences` instance and the container resolves the saved locale itself
- `HabitLoopApp` converted to `ConsumerWidget` watching `localeOverrideProvider` and forwarding it to `MaterialApp.locale`
- `main.dart` loads `SharedPreferences` before `runApp` and passes it to `AppContainer.overrides`
- `test/infrastructure/locale/data/shared_preferences_locale_service_test.dart` — 8 tests: save/read round-trip for en/fr/de/ru, clearLocale returns null, invalid stored value returns null, overwrite reflects on next read
- `test/infrastructure/locale/data/noop_locale_preference_service_test.dart` — 4 tests: getSavedLocale returns null, saveLocale/clearLocale are no-ops, no state leak
- `test/infrastructure/locale/fake_locale_preference_service.dart` — shared fake for WU3 UI tests
- `test/infrastructure/injections/app_container_test.dart` extended — 4 new tests: localePreferenceServiceProvider resolves to noop default, localeOverrideProvider is null when not provided, both override correctly when provided, overrides list grows by 2
- 692 tests passing, analyzer clean

---

## [0.18.3] — 2026-05-06 (PR #51 merged)

### Added — Russian locale and language picker l10n keys (HAB-40 WU1)

- [user] `lib/l10n/app_ru.arb` added with Russian translations for all 55 existing l10n keys
- 6 new language picker keys (`languagePickerTitle`, `languageEnglish`, `languageFrench`, `languageGerman`, `languageRussian`, `languageSystem`) added to all four ARB files (en, fr, de, ru) and regenerated via `flutter gen-l10n`
- `ru` declared in `ios/Runner/Info.plist` `CFBundleLocalizations` array (iOS per-app language picker support)
- `<locale android:name="ru"/>` added to `android/app/src/main/res/xml/locales_config.xml` (Android 13+ locale config)
- Russian plural categories (`few`/`many`) added; `statsShowups` pluralised correctly across all four locales
- `test/l10n/russian_locale_test.dart` — 8 new tests: `AppLocalizations` resolves for `Locale('ru')` and all 6 new language picker keys are non-empty in en/fr/de/ru
- 674 tests passing, analyzer clean

---

## [0.18.2] — 2026-05-06 (PR #50 merged)

### Changed — In-memory stats cache in PactStatsService (HAB-51)

- [user-none]
- `PactStatsService` gained a private `Map<String, PactStats> _statsCache` keyed by pact ID; constructor is no longer `const`
- `currentStats()` made async with lazy cache-on-miss: when called with empty showups, checks cache first; on miss loads from `ShowupRepository`, writes to cache, and returns; on hit returns immediately without a DB round-trip; when called with non-empty showups, computes fresh stats without touching cache
- `persistShowupStatus()` evicts the stale cache entry before `_syncStatsBestEffort`, which then repopulates it via `syncStats → persistStats`
- `stopPact()` evicts-only after the stop transaction (showups are deleted so there is no valid state to cache)
- `onPactCompleted(String pactId)` added — evicts the cache entry; called internally by `PactService.updatePact()` when pact status transitions to `completed`, keeping `PactDetailViewModel` fully unaware of cache management
- `PactService` now holds a required (non-nullable) `PactStatsService`; `pactServiceProvider` in `app_providers.dart` wires it in
- `docs/ARCHITECTURE.md` updated with accurate cache lifecycle description and circular-dependency warning
- 668 tests passing, analyzer clean

---

## [0.18.1] — 2026-05-06 (PR #49 merged)

### Changed — Centralise dependency injection into lib/infrastructure/injections/ (HAB-52)

- [user-none]
- `lib/infrastructure/injections/app_providers.dart` — single canonical file declaring all 9 app-wide Riverpod providers (analytics, crashlytics, logging, remote config, pact/showup repositories, pact transaction service, pact service, pact stats service); replaces 5 deleted `providers/` files and removes provider declarations from 3 application-service files
- `lib/infrastructure/injections/app_container.dart` — `AppContainer` static class exposing `AppContainer.overrides(...)` that accepts constructed service instances and returns the full `List<Override>` for `ProviderScope`; `main.dart` calls only this method
- `main.dart` slimmed to call `AppContainer.overrides(...)`; no provider declarations or override lists remain inline
- 5 old `providers/` files deleted (analytics, crashlytics, logging, remote config, persistence/repository_providers.dart); 4 empty directories removed
- 4 duplicate slice-local repository provider aliases removed; `PactListViewModel` and `ShowupDetailViewModel` now read canonical providers from `injections/`
- `ShowupDetailViewModel` refactored to use `ref.read(pactStatsServiceProvider)` instead of inline `PactStatsService(...)` construction — `PactStatsService` is now a singleton provider
- `docs/INJECTIONS.md` added — full dependency graph, provider table, and instructions for adding new providers
- `docs/ARCHITECTURE.md` updated with `injections/` directory entries
- `test/infrastructure/injections/app_container_test.dart` — smoke tests for `AppContainer`
- 644 tests passing, analyzer clean

---

## [0.18.0] — 2026-05-05 (PR #48 merged)

### Added — PactService façade and full SQLite wiring (HAB-11 Work Unit 4)

- `lib/slices/pact/application/pact_service.dart` — `PactService` application-layer façade that composes `PactRepository`, `ShowupRepository`, and `PactTransactionService`; `createPactFromBuilder()` delegates to the atomic `PactTransactionService.savePactWithShowups()` path (SQLite) or falls back to sequential saves with manual rollback (in-memory test path); view models no longer import repository or transaction providers directly
- `PactTransactionService` interface made non-nullable in `PactService`; `SqlitePactTransactionService` is the production implementation wired via `main.dart`; `InMemoryPactTransactionService` is provided for tests
- `lib/infrastructure/persistence/repository_providers.dart` — centralised Riverpod provider declarations for `SqlitePactRepository`, `SqliteShowupRepository`, and `PactTransactionService` so all infrastructure providers are declared in one place
- `main.dart` opens `HabitLoopDatabase`, constructs `SqlitePactRepository`, `SqliteShowupRepository`, and `PactTransactionService`, and wires them as the single app-wide repository sources via `ProviderScope` overrides; `InMemoryPactRepository` and `InMemoryShowupRepository` are no longer used at runtime
- [user] `_DatabaseErrorApp` widget displayed when the database fails to open, giving the user a visible error rather than a silent crash
- `PactCreationViewModel` and `PactDetailViewModel` refactored to delegate all persistence to `PactService` and `PactStatsService` respectively
- `PactStatsService` extended with `loadShowupsForPact()` helper so `PactDetailViewModel` can load showups without reaching into `showupRepositoryProvider`
- `pactServiceProvider` composed from the three lower-level providers; existing `ProviderContainer` overrides in tests continue to work
- 637 tests passing, analyzer clean

---

## [0.17.0] — 2026-05-05 (PR #47 merged)

### Added — Atomic pact creation and stop-pact transaction (HAB-11 Work Unit 3)

- [user-none]
- `lib/slices/pact/application/pact_transaction_service.dart` — `PactTransactionService` encapsulates two atomic operations: `savePactWithShowups(pact, showups)` wraps pact insert and showup batch-save in a single sqflite transaction so a showup-write failure can never leave an orphan pact row; `stopPactTransaction(pactId, stoppedAt, reason)` atomically deletes pending showups and updates the pact status to stopped in one transaction
- `PactCreationViewModel` wired to call `PactTransactionService.savePactWithShowups()` instead of the previous two-step insert + saveShowups path, resolving the HAB-16 rollback tech debt atomically
- `PactDetailViewModel` wired to call `PactTransactionService.stopPactTransaction()` for the stop-pact flow, replacing the previous separate delete + update calls
- HAB-16 (rollback exception masks original error in pact creation) resolved: the orphan-pact risk is eliminated because the transaction rolls back atomically on any failure
- 626 tests passing, analyzer clean

---

## [0.16.0] — 2026-05-05 (PR #46 merged)

### Added — SQLite database and repository implementations (HAB-11 Work Unit 2)

- [user-none]
- `lib/infrastructure/persistence/habit_loop_database.dart` — `HabitLoopDatabase` owns the sqflite `Database` singleton lifecycle and schema v1 DDL via `runMigrations` (public static for test injection); canonical DDL for `pacts` and `showups` tables consolidated here
- `lib/slices/pact/data/sqlite_pact_repository.dart` — `SqlitePactRepository` — production `PactRepository` implementation backed by sqflite; uses `PactMapper` for row conversion; `updatePact` issues a targeted `UPDATE` on the primary key
- `lib/slices/showup/data/sqlite_showup_repository.dart` — `SqliteShowupRepository` — production `ShowupRepository` implementation; `getShowupsForDate` and `getShowupsInRange` use epoch-ms boundaries derived from local-time midnight via `ShowupDateUtils`; `saveShowups` uses `INSERT OR REPLACE` for idempotent batch upserts
- `sqflite_common_ffi` added as dev dependency to enable in-memory SQLite for unit tests on macOS
- Schema DDL comment blocks removed from `PactMapper`/`ShowupMapper` (canonical DDL now lives in `HabitLoopDatabase.runMigrations`)
- `docs/ARCHITECTURE.md` updated with new file entries, updated Data layer description, and updated Persistence infrastructure paragraph
- `AGENTS.md` workflow updated: simulator smoke test step removed from the standard delivery workflow
- 614 tests passing (561 pre-existing + 53 new), analyzer clean

---

## [0.15.0] — 2026-05-03 (PR #45 merged)

### Added — SQLite mappers and codec (HAB-11 Work Unit 1)

- [user-none]
- `lib/infrastructure/persistence/schedule_codec.dart` — JSON codec for `ShowupSchedule` supporting all three schedule types (`daily`, `weekly`, `monthly`); encodes to a plain `Map<String, dynamic>` suitable for SQLite text columns
- `lib/infrastructure/persistence/pact_mapper.dart` — bidirectional mapper between `Pact` domain model and SQLite row (`Map<String, dynamic>`); handles all nullable fields and delegates schedule serialisation to `ScheduleCodec`
- `lib/infrastructure/persistence/showup_mapper.dart` — bidirectional mapper between `Showup` domain model and SQLite row; handles `ShowupStatus` and `Duration` round-trips
- `docs/ARCHITECTURE.md` updated with `persistence/` directory tree entry and Persistence paragraph describing the mapper/codec layer
- `AGENTS.md` step 3 updated: branch must be created from `origin/main`
- 561 tests passing, analyzer clean

---

## [0.14.0] — 2026-05-03 (PR #44)

### Changed — Single-ticket workflow, pre-merge housekeeping, CI version-tag fix

- [user-none]
- `AGENTS.md`: only one ticket may be in progress at a time; `docs/BACKLOG.md` `## In Progress` section signals the active ticket; step 3 marks the ticket there when the branch is created; step 16 revised — product-owner commits CHANGELOG + BACKLOG + pubspec bump onto the feature branch *before* merge so all housekeeping lands in one squash commit; version bump no longer requires user approval
- `docs/BACKLOG.md`: `## In Progress` section added at the top; HAB-47 and HAB-49 removed from Unscheduled (merged)
- `.github/workflows/ci.yml` `version-tag` job: `git pull --rebase` moved to *before* the `sed`/commit instead of after — eliminates the rebase conflict when a prior build-number bump landed on main while the job was waiting for distribute steps to finish

---

## [0.13.0] — 2026-05-03 (PR #42 + PR #43)

### Added — Experiment registry and experimentation stack documentation (HAB-49)

- [user-none]
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

- [user-none]
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

- [user] The app launch screen no longer shows a white flash on iOS
- `LaunchScreen.storyboard` background changed from white to brand teal (`#00637B`); transparent foreground icon (from Android adaptive icon layer) replaces the flat opaque icon — logo now floats seamlessly on the teal background, matching Android's splash screen
- `Main.storyboard` root view background changed from white to teal (`#00637B`) — eliminates the white flash during Firebase init between launch screen dismissal and first Flutter frame
- `SceneDelegate.swift` sets `UIWindow.backgroundColor` to teal (`#00637B`) — closes the last remaining white gap caused by the UIKit window default white showing through the transparent `FlutterViewController` view during engine init
- `dashboard_page_ios.dart`: removed `ColoredBox(systemBackground)` that forced white on the calendar strip and showup list while the nav bar and `PactsPanel` used `colorScheme.surface` (mint); set `CupertinoListTile.backgroundColor` to transparent for full visual consistency
- `ios/Podfile.lock`: `firebase_remote_config` and `FirebaseABTesting` pods added (were missing despite being declared in `pubspec.yaml` since v0.10.3)
- 469 tests pass, analyzer clean

---

## [0.11.10] — 2026-04-29 (HAB-17)

### Refactored — Extract PactBuilder from PactCreationState (HAB-17)

- [user-none]
- `PactBuilder` introduced in `lib/features/pact/domain/pact_builder.dart`: owns the 7 pact-data fields (`habitName`, `startDate`, `endDate`, `showupDuration`, `scheduleType`, `schedule`, `reminderOffset`), the `_addMonths` month-clamping helper, and the `ScheduleType` enum; exposes validity predicates (`isDateRangeValid`, `isShowupDurationValid`, `isScheduleSet`, `isHabitNameValid`, `isComplete`) and a `build({id, createdAt})` factory that throws `StateError` if incomplete
- `PactCreationState` slimmed to wizard-navigation concerns only: holds `builder: PactBuilder`, `currentStep`, `commitmentAccepted`, `isSubmitting`, `submitError`; data-field params removed from `copyWith`; proxy getters (`habitName`, `startDate`, etc.) delegate to `builder` so zero widget changes were needed; `canAdvanceFromStep` is now a pure dispatch table routing each step to the corresponding builder predicate
- `PactCreationViewModel` gains private `_updateBuilder()` helper; all data-field setters route through it; `submit()` guard replaced with `if (!state.builder.isComplete) return;` and manual `Pact(...)` constructor replaced with `state.builder.build(id: ..., createdAt: now)`
- `ScheduleType` re-exported from `pact_creation_state.dart` so all existing import sites remain unchanged
- 43 new `PactBuilder` tests; `PactCreationState` tests rewritten to cover dispatch-table delegation and proxy-getter correctness; 468 tests pass, analyzer clean

---

## [0.11.9] — 2026-04-27 (PR #36 merged)

### Added — iOS builds wired to Firebase App Distribution (HAB-28)

- [user-none]
- `build-ios` job added to `.github/workflows/ci.yml` running on `macos-latest`; builds a release IPA using the Apple distribution certificate and ad-hoc provisioning profile stored as GitHub Actions secrets (`IOS_CERTIFICATE_P12`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE`, `IOS_TEAM_ID`)
- `distribute-ios` job added; uploads the signed IPA to Firebase App Distribution using the `FIREBASE_IOS_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_IOS` secrets, running on every merge to `main` only
- `version-tag` job updated to emit `both`, `android`, or `ios` suffix depending on which platform builds succeeded, and pinned to the triggering commit SHA to close a race window where a concurrent build-number bump could cause the tag to target the wrong commit
- `docs/VERSIONING.md` updated with the `FIREBASE_IOS_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_IOS` secrets, the revised CI pipeline diagram, and the race-window fix explanation

---

## [0.11.8] — 2026-04-27 (PR #38 merged)

### Fixed — CupertinoDynamicColor dark-mode resolution in ShowupStatusColors (HAB-41)

- [user] Calendar strip dots and showup status icons now correctly adapt to dark mode on iOS
- `ShowupStatusColors.cupertino` const factory removed; both iOS dashboard call sites now resolve `CupertinoColors.activeGreen`, `CupertinoColors.destructiveRed`, and `CupertinoColors.systemGrey` via `resolveFrom(context)` before passing them to the `ShowupStatusColors` constructor, restoring correct light/dark adaptation for calendar-strip dots and showup tile icons in iOS dark mode
- 404 tests pass, analyzer clean

---

## [0.11.7] — 2026-04-27 (PR #37 merged)

### Changed — Extract shared formatLocaleDate helper to eliminate six-site duplication (HAB-42)

- [user-none]
- `formatLocaleDate(BuildContext context, DateTime date)` helper added to `lib/l10n/date_formatters.dart` as the single canonical definition of the `DateFormat.yMd(locale).format(date)` pattern
- All six previous call sites unified: inline usages in `pact_duration_step_ios.dart`, `pact_duration_step_android.dart`, `pact_detail_page_ios.dart`, and `pact_detail_page_android.dart` replaced; `formatPactDate` in `pact_creation_formatters.dart` and `formatShowupDate` in `showup_formatters.dart` delegated to the shared helper
- `docs/ARCHITECTURE.md` updated to document `lib/l10n/date_formatters.dart`
- 402 tests pass, analyzer clean

---

## [0.11.6] — 2026-04-26 (PR #35 merged)

### Fixed — Align pubspec.yaml version name with changelog (HAB-43)

- [user-none]
- `pubspec.yaml` version name bumped from `0.1.0` to `0.11.5` so Firebase App Distribution labels builds with the correct version instead of the initial scaffold value
- `AGENTS.md` workflow updated: step 10 now requires verifying that `pubspec.yaml` version name matches the latest `CHANGELOG.md` entry before committing, and updating it (with user approval) when a new changelog entry is added
- 399 tests pass, analyzer clean

---

## [0.11.5] — 2026-04-25 (PR #34 merged)

### Changed — Reduce duplicated iOS/Android dashboard widget logic (HAB-15)

- [user-none]
- Extracted shared formatter helpers — `pact_creation_formatters.dart`, `pact_formatters.dart`, `showup_formatters.dart` — replacing duplicated date, schedule, reminder, and status formatting logic across commitment steps, schedule steps, pact detail pages, showup detail pages, and the pacts summary bar
- Extracted `ShowupStatusColors` — a platform-agnostic colour-role resolver with Cupertino and Material factory constructors, replacing inline status-colour switches in both dashboard pages and showup tile implementations
- Extracted `ShowupStatusDots` — a platform-agnostic calendar-strip dot widget encapsulating the 1/2/3/4+ overflow layout and key naming, replacing `_buildDots()` in both dashboard pages
- Extracted `SummaryRow` — a platform-agnostic two-column label/value row for the commitment step summary card, replacing `_SummaryRow` in both commitment step files
- `docs/ARCHITECTURE.md` updated to document the expanded `generic/` responsibilities
- 399 tests pass, analyzer clean, dart format clean

---

## [0.11.4] — 2026-04-21 (PR #33 merged)

### Changed — Code quality baseline and dart format enforcement (HAB-33)

- [user-none]
- 13 lint rules added to `analysis_options.yaml` covering readability (`always_declare_return_types`, `avoid_print`, `prefer_single_quotes`, etc.), safety (`avoid_dynamic_calls`, `cast_nullable_to_non_nullable`), and Flutter-specific concerns (`use_build_context_synchronously`, `sized_box_for_whitespace`)
- `dart format --line-length 120` applied across the entire codebase in a dedicated formatting commit, keeping style-only changes separate from functional work
- CI (`github/workflows/ci.yml`) gains a `dart format --output=none --set-exit-if-changed` check on every push and PR, excluding generated files (`firebase_options.dart`, `lib/l10n/generated/*`)
- `AGENTS.md` and `.claude/agents/developer.md` updated to require a formatting commit (separate from functional commits) as part of the standard ticket delivery workflow; worktree-per-issue convention documented throughout

---

## [0.11.3] — 2026-04-21 (PR #32 merged)

### Changed — Per-app language selection (HAB-39)

- [user] `CFBundleLocalizations` array added to `ios/Runner/Info.plist` listing `en`, `fr`, `de`, so iOS Settings shows a per-app language picker under the app's entry (iOS 13+)
- [user] `android/app/src/main/res/xml/locales_config.xml` created with the three supported locales and referenced via `android:localeConfig` on the `<application>` element in `AndroidManifest.xml` (Android 13+ / API 33; older versions are unaffected)
- No Dart changes required — Flutter's existing `AppLocalizations` setup already handles locale switching once the platform declarations are in place

---

## [0.11.2] — 2026-04-21 (PR #31 merged)

### Changed — Dark mode support (HAB-37)

- `darkMaterialTheme` added to `HabitLoopTheme` using Material3 container tokens so all surfaces, text, and icons adapt automatically to the system colour scheme
- [user] `ThemeMode.system` wired into `MaterialApp` so the app follows the device's light/dark preference without any manual toggle
- `CupertinoTheme` brightness propagated from the active `BuildContext` so iOS widgets also respond correctly to dark mode
- [user] All hardcoded non-adaptive colours replaced with Material3 container tokens across Android widgets (Dashboard, Pact creation wizard, Pact detail, Showup detail, pacts panel, calendar strip, status dots, tiles)

---

## [0.11.1] — 2026-04-21 (PR #30 merged)

### Changed — Lock app to portrait orientation (HAB-38)

- [user] `Info.plist` updated to list only `UIInterfaceOrientationPortrait` in `UISupportedInterfaceOrientations` (iPhone), so iOS phones stay portrait-only regardless of device rotation
- iPad landscape support preserved in `UISupportedInterfaceOrientations~ipad` to comply with App Store guideline 10.1, which requires iPad apps to support both landscape orientations
- [user] `AndroidManifest.xml` `MainActivity` entry updated with `android:screenOrientation="portrait"` so Android devices remain locked to portrait

---

## [0.11.0] — 2026-04-20 (PR #29 merged)

### Fixed — iOS home indicator gesture on dashboard bottom sheet (HAB-36)

- [user] The swipe-up home gesture on iPhone now works correctly when the pacts panel is visible
- Removed the invisible gesture-blocking overlay that was preventing the native iOS swipe-up home gesture while the dashboard bottom sheet was visible; the `DraggableScrollableSheet` now receives gestures correctly without any custom bottom reserve
- The mint safe-area visual treatment (achieved via `CupertinoPageScaffold.backgroundColor`) is preserved, so no white stripe reappears below the bottom sheet
- Focused widget test added to `dashboard_page_ios_test.dart` asserting that no custom home-indicator reserve or blocking overlay is present in the widget tree

---

## [0.10.4] — 2026-04-19 (PR #28 merged)

### Added — App design foundation and launcher icon (HAB-35)

- Shared Habit Loop visual foundation added in `lib/theme/`: Material and Cupertino themes now use the same teal/growth/sunrise palette, and pact status colors consume semantic app colors instead of ad-hoc Material defaults
- [user] New Habit Loop app icon source added under `assets/app_icon/` and integrated into iOS and Android launcher assets, using the approved original icon composition with opaque iOS PNGs
- [user] Android adaptive launcher icon and splash screen now share the same teal background color and tuned foreground sizing so the icon fills the launcher surface without the previous visible clipping
- [user] iOS pact creation now includes a small step indicator using the shared palette, improving consistency with the newly defined app visual language
- iOS dashboard keeps the bottom safe-area visually aligned with the mint bottom sheet via the scaffold background, with focused test coverage documenting that no custom home-indicator overlay or reserve is used
- `docs/ARCHITECTURE.md` updated to document the shared theme layer and app icon asset source; tests added for the theme, iOS pact creation step indicator, and iOS dashboard safe-area treatment

---

## [0.10.3] — 2026-04-19 (PR #27 merged)

### Added — Firebase Remote Config integration (HAB-25)

- [user-none]
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

- [user-none]
- `PactCreationState` constructor and `PactCreationViewModel.setStartDate()` now normalize `startDate` to midnight, preventing a wall-clock time component from causing `duration_days` in `pact_created` analytics to under-count by 1 and `daysActive` in `pact_stopped` to report 0 when a pact is stopped the morning after an evening creation
- `pactDetailNowProvider` (`Provider<DateTime>`) extracted and wired into both `load()` (auto-completion check) and `stopPact()` (analytics), matching the `showupDetailNowProvider` and `pactCreationTodayProvider` pattern; `PactDetailScreen.initState()` and `onStopPact()` both invalidate the provider before use so the clock is always fresh

---

## [0.10.1] — 2026-04-18 (PR #21 merged)

### Fixed — Pact stats and dashboard analytics fixes (HAB-30, HAB-31, HAB-32)

- [user] Pact statistics are now preserved correctly after stopping a pact
- `pact_created` analytics now reports inclusive `duration_days`, aligning daily 6-month pact duration semantics with `showups_expected` and removing the apparent off-by-one mismatch
- Stopped pacts now preserve historical showup stats after active showups are deleted, and showup status changes refresh persisted pact stats through a single service boundary
- Dashboard `screen_view` analytics now fire every time the dashboard becomes visible again after returning from pact creation, pact detail, or showup detail flows

## [0.10.0] — 2026-04-17 (PR #20 merged)

### Added — Firebase Crashlytics integration (HAB-29)

- `firebase_crashlytics` SDK added to `pubspec.yaml`; a new `crashlytics` vertical slice introduces `CrashlyticsService` (abstract interface with a strict no-throw contract), `FirebaseCrashlyticsService` (backed by `FirebaseCrashlyticsClientAdapter`), and `NoopCrashlyticsService`
- `FlutterError.onError` and `PlatformDispatcher.instance.onError` wired to Crashlytics in `main.dart` so both Flutter-layer and native crashes are captured in release builds; debug and profile builds fall back to `NoopCrashlyticsService`
- `crashlyticsServiceProvider` provided via Riverpod so the service can be overridden in tests; `FakeCrashlyticsService` in `test/crashlytics/` for dependency injection
- `NoopAnalyticsService` and `NoopCrashlyticsService` now log via `debugPrint` in debug/profile builds for easier local debugging
- [user] `Pact.createdAt` field added; `ShowupGenerationService.ensureShowupsExist` and `ShowupGenerator.countTotal` now respect it to prevent past-due intra-day showups from being resurrected on dashboard load or causing a ghost "1 remaining" in pact stats
- `ARCHITECTURE.md` corrected: raw `FirebaseCrashlytics` SDK is referenced both via the adapter and directly in pre-`runApp` error handlers

---

## [0.9.5] — 2026-04-11 (PR #19 merged)

### Added — Firebase Analytics integration (HAB-26)

- [user-none]
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

- [user-none]
- GitHub Actions `distribute-android` job updated to upload the Android AAB to Firebase App Distribution on every merge to `main` using the Firebase App Distribution GitHub Action
- `FIREBASE_APP_ID_ANDROID` and `FIREBASE_TOKEN` GitHub Actions secrets wired into the workflow; build artifacts flow from the `build-android` job via uploaded artifacts
- Distribution only runs on the `main` branch; feature branch builds continue to build without distributing or tagging

---

## [0.9.3] — 2026-04-10 (PR #17 merged)

### Added — Firebase project setup (HAB-27)

- [user-none]
- `firebase_core` added to `pubspec.yaml`; `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` called in `main.dart` before `runApp`, so all subsequent Firebase SDKs (Analytics, Remote Config, App Distribution) can be added without further wiring
- `com.google.gms:google-services` Gradle plugin applied to `android/settings.gradle.kts` and `android/app/build.gradle.kts`
- `ios/Runner.xcodeproj/project.pbxproj` updated with Firebase configuration entries
- `lib/firebase_options.dart` added to `.gitignore` alongside `google-services.json` and `GoogleService-Info.plist` — credentials are never committed; branch history cleaned with `git filter-repo` to remove accidentally committed secrets

---

## [0.9.2] — 2026-04-10 (PR #16 merged)

### Changed — Showup generation window and date arithmetic

- Replaced `DateTime(year, month, day + 7)` arithmetic in `pact_creation_view_model.dart` and `dashboard_view_model.dart` with `date.add(const Duration(days: 7))`, which handles month-end boundaries correctly and is consistent with the `_addMonths()` pattern introduced in v0.2.0
- [user] Expanded the showup generation window from 7 to 10 days to ensure the full 7-day calendar strip is always covered with a DST-safe buffer; updated tests to assert the wider window

---

## [0.9.1] — 2026-04-10 (PR #15 merged)

### Changed — Lazy DateTime candidate generation in ShowupGenerator

- [user-none]
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
- [user] Calendar strip `todayIndex` offset ramps gradually over the first 3 days (day 1: today at index 0, day 2: index 1, day 3: index 2, day 4+: centered at index 3) to avoid a visual jump when a pact is first created

---

## [0.8.0] — 2026-04-08 (PR #13 merged)

### Added — Showup detail screen

- `ShowupDetailState` and `ShowupDetailViewModel` (Riverpod `autoDispose` notifier) backed by `ShowupRepository`; loads showup and resolves the parent pact name for the header
- [user] iOS (`CupertinoPageScaffold`) and Android (`Scaffold`) detail screens: shows scheduled time, habit name, and showup status with Done / Failed action buttons
- [user] Auto-fail on open: if the screen is opened after the showup's scheduled window has passed (`now > scheduledAt + duration`), the showup is immediately persisted as `failed`; `nowProvider` is used so the clock is injectable and testable
- [user] Save Note button disabled until the note content differs from the persisted value, preventing spurious writes
- Split error fields: `markError` for Done/Failed status mutations and `noteError` for note saves, so each action reports failures independently
- [user] Localised `"(habit deleted)"` fallback displayed when the parent pact can no longer be found in the repository
- [user] Dashboard showup tiles now carry a chevron and navigate to the detail screen; `nowProvider` invalidated on return so stale timestamps do not persist across navigations
- 12 new l10n keys across EN / FR / DE: `showupDetailTitle`, `showupDone`, `showupFailed`, `showupPending`, `markDone`, `markFailed`, `noteLabel`, `notePlaceholder`, `saveNote`, `markError`, `saveNoteError`, `habitDeleted`

---

## [0.7.1] — 2026-04-05 (PR #12 merged)

### Changed — Agent comment prefixes for distinguishability

- [user-none]
- Tech Lead PR comments now prefixed with **[Tech Lead]** and Code Reviewer PR comments with **[Code Reviewer]** on all inline and general comments, so both agents' findings are distinguishable when reviewing in parallel

---

## [0.7.0] — 2026-04-05 (PR #11 merged)

### Added — Developer agent for TDD feature implementation

- [user-none]
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

- [user-none]
- Tech Lead agent (`.claude/agents/tech-lead.md`, model `claude-opus-4-6`) that produces structured implementation plans from Linear issues: dependencies, models, UI changes, test strategy, ordered phases, and Developer work units
- `CLAUDE.md` workflow updated: step 1 now invokes the Tech Lead agent for large changes instead of producing plans inline; step 11 invokes tech-lead and code-reviewer in parallel (they check independent concerns — architectural vs runtime/launch)
- `model: claude-opus-4-6` field added to `tech-lead.md`; `model: claude-sonnet-4-6` added to `product-owner.md` and `code-reviewer.md` frontmatter
- `code-reviewer.md` updated with an explicit pre-reporting reasoning checklist (trigger sequence, existing handling, test coverage, worst-case outcome) — a finding is only reported when all four questions can be answered concretely
- `docs/AGENTS.md` updated to mark Phase 3 Done and record next actions

---

## [0.5.0] — 2026-04-04 (PR #9 merged)

### Added — Multi-agent workflow and Linear integration

- [user-none]
- Product Owner agent (`.claude/agents/product-owner.md`) wired into session-start and post-merge workflow: reads Linear backlog, summarises released and remaining work, manages BACKLOG.md and CHANGELOG.md regeneration from Linear
- `.mcp.json` committed — Linear MCP server configured for the workspace, enabling all agents to query and update Linear issues
- `.claude/agents/` directory committed to the repository; `code-reviewer.md` (previously untracked) and `product-owner.md` now versioned
- `docs/AGENTS.md` describing the full multi-agent plan (Product Owner, Tech Lead, Developer, Code Reviewer)
- Backlog and changelog migrated to Linear as the single source of truth: `BACKLOG.md` is now generated from open Linear issues; `CHANGELOG.md` is maintained by the Product Owner agent after each merge
- HAB-10 (v0.5.0 milestone) closed as Done; milestone reached 100% completion

---

## [0.4.0] — 2026-04-04 (PR #7 merged)

### Added — Pact detail screen and persistent pacts panel

- [user] Pact detail screen: stats (done / failed / remaining or cancelled / streak), timeline (start date, end date, days remaining), stop pact with confirmation dialog and optional explanation
- [user] Pact detail screen is accessible for active, stopped, and completed pacts
- [user] Persistent `DraggableScrollableSheet` panel on the dashboard listing all pacts with filter chips (Active / Done / Stopped) and a summary bar
- [user] Tapping a pact tile navigates to its detail screen; returning refreshes both the pact list and the dashboard calendar
- [user] Auto-completion: `PactDetailViewModel.load()` transitions an active pact to `completed` when its end date has passed (`daysLeft ≤ 0`) or all showups are resolved
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

- [user] Warning dialog before pact creation when the user already has 3 or more active pacts; plural-aware copy in EN/FR/DE
- iOS warning uses `CupertinoAlertDialog`; Android uses `AlertDialog`
- [user] Crossfade animation when switching days in the calendar strip
- iOS nav-bar `+` button hidden on empty state (matching Android FAB behaviour)
- New l10n keys: `cancel`, `tooManyPactsTitle`, `tooManyPactsBody` (plural), `tooManyPactsConfirm`

### Changed — Calendar strip dot layout

- [user] 1 showup → 1 dot; 2 → 2 dots on one row; 3 → 2+1 rows; 4+ → single large overflow dot
- [user] Overflow dot colour: grey while any showup is still pending; green if all resolved and done ≥ failed; red if failed > done
- Overflow dot key includes date (`status-dot-overflow-YYYY-MM-DD`) to prevent key collisions across the 7-day strip

### Fixed

- TOCTOU race: `_creatingPact` flag prevents double-tap from bypassing the pact count guard
- `onCreatePact` typed as `AsyncCallback` so exceptions after `await` are not silently dropped
- `hasActivePactsProvider` now invalidated on return from pact creation via the warning-dialog path

---

## [0.2.0] — 2026-04-03 (PR #4 merged)

### Added — Dashboard wiring

- [user] Showups now appear in the calendar after you create a pact
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

- [user-none]
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

- [user] 5-step wizard: commitment confirmation → habit name → pact duration → showup duration → schedule → reminder
- [user] `ShowupSchedule` supporting three modes: every day at a time, specific weekdays, specific days of the month
- `PactCreationState` and `PactCreationViewModel` (Riverpod notifier) managing wizard state
- `PactRepository` interface and `InMemoryPactRepository` implementation
- `Pact` model and `PactStatus` enum (`active`, `stopped`, `completed`)
- Platform-split UI: separate iOS (`CupertinoPageScaffold`) and Android (`Scaffold`) widgets for each step
- Fix: schedule step no longer loses entered entries when navigating back

### Added — Dashboard

- [user] Dashboard screen with a 7-day calendar strip (3 days before / today / 3 days after)
- Today's showup list placeholder (empty state)
- Platform-split UI: `DashboardPageIos` and `DashboardPageAndroid`
- `DashboardState` and `DashboardViewModel`

---

## [0.0.1] — 2026-01-?? (initial scaffold)

### Added

- [user-none]
- Flutter project scaffold targeting iOS and Android
- Riverpod for state management and dependency injection
- sqflite dependency for local storage (not yet used)
- Localizations in English, French, and German (`flutter gen-l10n`, output to `lib/l10n/generated/`)
- `analysis_options.yaml` with `package:flutter_lints`
- CI/CD pipeline (GitHub Actions): test → resolve-version → build-android / build-ios → distribute → version tag
