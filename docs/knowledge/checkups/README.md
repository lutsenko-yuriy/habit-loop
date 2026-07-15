# Checkup ledger

Tracks due status and open findings for the two-tier periodic code-quality checkup defined in [ADR-0003](../decisions/ADR-0003-two-tier-periodic-code-quality-checkup.md). `scripts/checkup/due.py` reads the **Cadence & due status** table below to report which tier(s) are due; the `/checkup` skill updates this file after each run.

## Cadence & due status

Each tier is tracked as "not yet done this period" — a period label, not an exact-day match — so it stays flagged as overdue until actually run (see ADR-0003). `Period covered` is the period label (`YYYY-MM` for light, `YYYY-Qn` for heavy) of the most recently completed run.

| Tier | Cadence | Last run | Period covered | Next due |
|---|---|---|---|---|
| Light | 1st of every calendar month | 2026-07-16 | 2026-07 | — |
| Heavy | 14th of Jan/Apr/Jul/Oct | never | — | now |

## Open findings

Findings needing human decision or larger effort, each carrying an explicit deadline — no individual Linear ticket is filed (per ADR-0003). Classified using [Fowler's Technical Debt Quadrant](https://martinfowler.com/bliki/TechnicalDebtQuadrant.html) before being written up.

| ID | Opened | Tier | Dimension | Debt quadrant | Summary | Deadline | Write-up |
|---|---|---|---|---|---|---|---|
| CHK-2026-07-16-light-1 | 2026-07-16 | Light | Doc-reality drift / Scenario quality | Prudent-inadvertent | Dangling "Load more" pagination test stub (`pact_timeline_flow_test.dart`) — pagination was dropped from `PactTimelineService` mid-HAB-116, docs now corrected, but the stub and the product question (implement for real, or delete) remain open | 2026-08-15 | [CHK-2026-07-16-light](CHK-2026-07-16-light.md) |

## Resolved findings

Archive of findings once fixed or otherwise closed out.

| ID | Opened | Resolved | Tier | Dimension | Summary | Write-up |
|---|---|---|---|---|---|---|
| _none yet_ | | | | | | |
