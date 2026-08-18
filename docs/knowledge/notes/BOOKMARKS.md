# Bookmarks

Hand-authored vocabulary of bookmarks used across `docs/knowledge/notes/`. Each note's
`bookmarks:` frontmatter must use only names from this table (lowercase kebab-case). Add
a new row when a genuinely new theme emerges from the corpus — don't invent a synonym for
something already covered here.

`scripts/notes/index.py --check` fails a note that uses a bookmark not listed below.

Populated by the WU2 corpus backfill (HAB-221); re-validated quarterly as part of the
heavy `/checkup` tier.

| Bookmark | Meaning |
|---|---|
| `ci-flakiness` | CI-only integration-test flakiness — timing races, emulator/simulator quirks, non-reproducible-locally failures. |
| `debugging-methodology` | Root-cause discipline: hypothesis-first, validate live instead of re-guessing from code, diagnostic instrumentation over trial-and-error. |
| `multi-wu-scope` | Multi-WU ticket structure — scope summaries surviving compaction, WU splitting/sequencing, resuming after a break. |
| `scope-creep` | Mid-ticket scope expansion — folding unrelated discoveries into the current ticket instead of deferring them. |
| `review-findings` | `review-architecture`/`audit-code` catching a real bug, and the discipline of fixing/replying immediately. |
| `debrief-timing` | Where `/debrief` sits relative to `/ship`/merge in the workflow, and slips in that ordering. |
| `changelog-versioning` | CHANGELOG tag taxonomy, the `## [Unreleased]` batching design, and `pubspec.yaml` version-bump gating. |
| `appstore-ci` | Apple App Store Connect / TestFlight tooling friction — signing, secrets encoding, SDK requirements. |
| `widget-test-gotchas` | Flutter test-framework traps — `skipOffstage`, `dragUntilVisible`, `ensureVisible`, `pumpAndSettle` timing. |
| `l10n-glossary` | Translation/canonical-term drift across locales and the per-language GLOSSARY table. |
| `code-style` | Nesting, guard clauses, comment brevity/verbosity, and other CODE_STYLE.md-shaped findings. |
| `linear-efficiency` | Linear MCP token/tool-call usage and cost. |
| `research-methodology` | Research-workflow shape — surveying alternatives first, citing sources, scoping constraints/MoSCoW. |
| `ui-design-iteration` | Live/running-app review triggering visual or layout rework after implementation looked "done". |
| `verify-from-source` | Verifying a subagent's or skill's self-reported outcome against the actual Linear/git/API state. |
| `feature-toggle` | Remote Config kill-switch defaults, rollout sequencing, and console/code sync gaps. |
| `knowledge-base-process` | The `/note`/`/debrief` mechanism itself — notes file conventions, staging, presentation at debrief start. |
| `dead-code` | Dead code or unused-functionality discovery and removal. |
| `stale-ticket` | A ticket's description no longer matching current reality by the time it's picked up. |
| `planning-gaps` | Gaps surfaced only during implementation that the `/plan` pass should have caught — algorithm/API mismatches, mis-sequenced WUs, narrow option sets. |
| `cross-project-sync` | Keeping this repo's harness (skills/workflow docs) in sync with the sibling Yuriys-agentic-boyz project. |
| `postmortem-workflow` | Post-fix root-cause investigation ticket structure — origin tracing, deadline discipline, distinguishing from pre-fix troubleshooting. |
| `multi-project-scope` | Whether/how sub-projects sharing a repo (e.g. Flutter app vs. Python/Bash tooling) need separate plan/implement/review cycles, repo boundaries, or orchestration. |
| `trivial-change-scope` | Recognizing content-only changes (copy/asset/literal edits) that don't need the full review/release ceremony. |
