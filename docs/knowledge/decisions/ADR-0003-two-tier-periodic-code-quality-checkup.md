# ADR-0003 — run a two-tier (light/heavy) periodic checkup for non-mechanical code quality dimensions

## Status
`accepted`

## Context
Some code quality dimensions can't be measured mechanically — unused functionality, scenario quality, structural clarity, glossary/naming drift, doc-reality drift, cross-screen UX consistency, accessibility, and feature-flag lifecycle. `/review-architecture` and `/audit-code` catch what's fixable per-PR, immediately after implementation, but general project decay (drift, staleness) accumulates silently because no single PR triggers a look at it. Full survey with all sources: `docs/knowledge/notes/HAB-144.md`.

## Decision
Adopt a two-tier periodic checkup, complementary to (not replacing) `/review-architecture` and `/audit-code`:

- **Light checkup** — unused functionality, scenario quality, glossary/naming drift, doc-reality drift, feature-flag lifecycle. Due the 1st of every calendar month, tracked as "not yet done this month" (not an exact-day match, so it stays flagged until actually run). Modelled on feature-flag audit practice, where an explicit per-item review-by date (not a relative "since last audit" counter) is standard specifically to survive irregular team cadence. [Statsig: Tips for Unused Feature Flag Clean-Up](https://www.statsig.com/perspectives/tips-for-unused-feature-flag-clean-up) · [FlagShark: Feature Flag Lifecycle](https://flagshark.com/blog/feature-flag-lifecycle-creation-cleanup-5-stages/)
- **Heavy checkup** — readability & structural clarity, cross-screen UX consistency, accessibility. Due the 14th of every quarter-anchor month (Jan/Apr/Jul/Oct), tracked as "not yet done this quarter." These three dimensions require a full sweep of the whole project, which precedent treats as a deeper, less-frequent pass: manual accessibility audits are commonly run quarterly/annually alongside continuous automated scans ([TheWCAG: Accessibility Audit Guide 2026](https://www.thewcag.com/accessibility-audit-guide)), and Nielsen Norman Group's heuristic evaluation — the closest analog for cross-screen UX consistency — is inherently a full-interface review exercise, not a quick spot check ([NN/g: How to Conduct a Heuristic Evaluation](https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/)).
- Either checkup can also be started on demand, independent of its due date.
- At session start, if a checkup is due, the session recommends running it instead of picking up a new ticket.
- Findings addressable immediately are fixed inline, per the Boy Scout Rule — "leave the code cleaner than you found it" ([Laws of Software Engineering: Boy Scout Rule](https://lawsofsoftwareengineering.com/laws/boy-scout-rule/)).
- Before being written up, each finding is classified using Fowler's Technical Debt Quadrant (deliberate vs. inadvertent × reckless vs. prudent) — most checkup findings are expected to land in "prudent-inadvertent" (design flaws only visible in hindsight), which is useful context for how urgently the deadline below should be set ([Fowler: Technical Debt Quadrant](https://martinfowler.com/bliki/TechnicalDebtQuadrant.html)).
- Findings needing human decision or larger effort are **not** filed as individual Linear tickets — instead written up debrief-style into the knowledge base, with an explicit deadline recorded as a dated line in a lightweight tracking doc. This deliberately deviates from the closest precedent, a "technical debt register" that recommends *against* hard deadlines in favor of "fix when back in that code area" — a trigger that doesn't exist for a solo developer the way it does for a multi-feature team ([Mark Heath: How should you track technical debt?](https://markheath.net/post/technical-debt-register)).
- NN/g's heuristic evaluation normally calls for 3–5 independent evaluators; adapted here to a single agent-assisted pass, since there's no dedicated QA/second reviewer to run it as prescribed ([NN/g: How to Conduct a Heuristic Evaluation](https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/)).
- **Discovery outcome:** a dimension found to be mechanically measurable graduates into an automated CI check (HAB-143 territory), shrinking the manual checklist over time — cyclomatic complexity is a concrete candidate, since `dart_code_metrics`/DCM already ships a configurable metric for it ([DCM: Cyclomatic Complexity](https://dcm.dev/docs/metrics/function/cyclomatic-complexity/)).
- Per-dimension checklist heuristics and the actual `/checkup` skill are deliberately **not** designed here — this ticket is research-only (no production code, per `RESEARCH_WORKFLOW.md`); both are scoped into a follow-up implementation ticket created after this research is debriefed.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| File a Linear ticket per checkup finding | Overkill overhead for a monthly self-review; a lightweight tracking doc with an enforced deadline preserves the forcing function without ticket ceremony |
| No enforced deadline on findings ("fix when back in that code area" — the technical-debt-register precedent) | Doesn't fit solo-dev context: there's no natural multi-person trigger for "back in that area," so an explicit deadline is needed to guarantee action |
| Literal NN/g heuristic evaluation (3–5 independent evaluators) | No dedicated QA/second reviewer exists — adapted to a single agent-assisted pass instead |
| Uniform monthly cadence for all 8 dimensions | The heavier dimensions require a full-project sweep and would make every monthly session too long to sustain solo — split into light/heavy tiers instead |
| Relative cadence ("every 3rd checkup") instead of a fixed calendar anchor | A fixed anchor (Jan/Apr/Jul/Oct) needs no extra state to track and is simpler to reason about than counting checkups |

## Related ticket
HAB-144 — full precedent survey and research notes: `docs/knowledge/notes/HAB-144.md`

## Date
2026-07-15
