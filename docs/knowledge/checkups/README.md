# Checkup ledger

Tracks due status and open findings for the two-tier periodic code-quality checkup defined in [ADR-0003](../decisions/ADR-0003-two-tier-periodic-code-quality-checkup.md). `scripts/checkup/due.py` reads the **Cadence & due status** table below to report which tier(s) are due; the `/checkup` skill updates this file after each run.

## Cadence & due status

Each tier is tracked as "not yet done this period" — a period label, not an exact-day match — so it stays flagged as overdue until actually run (see ADR-0003). `Period covered` is the period label (`YYYY-MM` for light, `YYYY-Qn` for heavy) of the most recently completed run.

| Tier | Cadence | Last run | Period covered | Next due |
|---|---|---|---|---|
| Light | 1st of every calendar month | 2026-07-16 | 2026-07 | — |
| Heavy | 14th of Jan/Apr/Jul/Oct | 2026-07-20 | 2026-Q3 | — |

## Open findings

Findings needing human decision or larger effort, each carrying an explicit deadline — no individual Linear ticket is filed (per ADR-0003). Classified using [Fowler's Technical Debt Quadrant](https://martinfowler.com/bliki/TechnicalDebtQuadrant.html) before being written up.

| ID | Opened | Tier | Dimension | Debt quadrant | Summary | Deadline | Write-up |
|---|---|---|---|---|---|---|---|
| CHK-2026-07-16-light-1 | 2026-07-16 | Light | Doc-reality drift / Scenario quality | Prudent-inadvertent | Dangling "Load more" pagination test stub (`pact_timeline_flow_test.dart`) — pagination was dropped from `PactTimelineService` mid-HAB-116, docs now corrected, but the stub and the product question (implement for real, or delete) remain open | 2026-08-15 | [CHK-2026-07-16-light](CHK-2026-07-16-light.md) |
| CHK-2026-07-20-heavy-1 | 2026-07-20 | Heavy | Readability & structural clarity | Prudent-inadvertent | `DashboardViewModel._loadInner` (~175 lines, 6 responsibilities) with duplicated gap-fill/auto-fail sweep loops | 2026-10-14 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-2 | 2026-07-20 | Heavy | Readability & structural clarity | Prudent-inadvertent | `_PactsPanelState.build` (357-line `build()`, 6-7 levels of nesting) — clearest God-widget in the codebase | 2026-09-01 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-3 | 2026-07-20 | Heavy | Readability & structural clarity | Prudent-inadvertent | Cupertino picker-sheet scaffold copy-pasted 5x in `schedule_step_ios.dart`, no Android equivalent | 2026-10-14 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-4 | 2026-07-20 | Heavy | Readability & structural clarity | Prudent-inadvertent | `_mergeRemotePact`/`_mergeRemoteShowup` duplicate merge-rule logic in `firestore_sync_service.dart` | 2026-10-14 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-5 | 2026-07-20 | Heavy | Cross-screen UX consistency | Prudent-inadvertent | Material icon in an otherwise-Cupertino iOS toolbar (`sync_status_handler.dart`), visible on launch | 2026-08-15 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-6 | 2026-07-20 | Heavy | Cross-screen UX consistency | Prudent-inadvertent | Inconsistent primary-button hierarchy on Android (`FilledButton`/`ElevatedButton`/`OutlinedButton` mixed with no emphasis logic) | 2026-09-01 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-7 | 2026-07-20 | Heavy | Cross-screen UX consistency | Prudent-inadvertent | No shared spacing/typography scale in `lib/theme/`; iOS text styling is all ad hoc `TextStyle`, no `CupertinoTheme` usage | 2026-10-14 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-8 | 2026-07-20 | Heavy | Accessibility | Reckless-inadvertent | No `Semantics`/`tooltip`/`semanticLabel` anywhere in the app; unlabeled destructive controls and sub-minimum tap targets on core flows (dashboard, pact creation) | 2026-08-15 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |
| CHK-2026-07-20-heavy-9 | 2026-07-20 | Heavy | Accessibility | Prudent-inadvertent | `CupertinoColors.systemGrey` secondary text fails WCAG AA contrast across iOS screens; `DateRowTile` default color is a latent contrast trap; day-circle digit has no `FittedBox` for large text scale | 2026-09-15 | [CHK-2026-07-20-heavy](CHK-2026-07-20-heavy.md) |

## Resolved findings

Archive of findings once fixed or otherwise closed out.

| ID | Opened | Resolved | Tier | Dimension | Summary | Write-up |
|---|---|---|---|---|---|---|
| _none yet_ | | | | | | |
