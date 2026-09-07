# ADR-0007 — keep the fixed nightly clock-window block as-is, and add a complementary break reminder rather than replacing it

## Status
`accepted`

## Context
HAB-247's debrief (2026-08-24) shipped a hard `UserPromptSubmit` block on Claude Code sessions between 23:00-08:00 (`nightly_block.sh`), after the user noticed working past 11pm may have reduced their own attentiveness/thoroughness. That's a single-lever intervention gated on time-of-day alone. HAB-251 researched whether time-of-day is actually the right proxy, or whether other factors (eye strain, ergonomics, mental load/fatigue) matter as much or more, and surveyed existing tools/practices. See `docs/knowledge/notes/HAB-251.md` for the full evidence table and trade-off analysis. Constraints: solo developer, no ongoing-manual-tracking overhead sustainable, pre-launch stage favors simplicity/reversibility (`docs/CONSTRAINTS.md`).

## Decision
Keep the existing fixed clock-window block unchanged — no evidence surfaced that it is mistargeted, only that it is unvalidated as *the single best* fatigue proxy (a literature gap, not a finding against it). Separately, add a lightweight break reminder (20-20-20-style, precedented by OSHA ergonomics guidance and the Talens-Estarelles et al. 2022 study) as a **complement**, addressing a different mechanism (eye strain accumulation during a session) than the clock block (late-night fatigue). The reminder should be checked on the next request (`UserPromptSubmit`-hook-triggered, mirroring `nightly_block.sh`/`alert.sh`'s existing pattern) rather than fired by a cron-like OS-level timer — the latter needs a separate scheduler (`launchd`), more moving parts, less reversible. Tracked for actual implementation under a small follow-up ticket, not built as part of this research ticket.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Replace the clock window with a session-duration trigger | No study found comparing this to time-of-day as a fatigue proxy — would swap one unvalidated signal for another, plus adds new state to track, for no evidenced gain |
| Add a self-report/checklist gate (e.g. periodic "still sharp?" prompt) | Requires ongoing manual input every session; `docs/CONSTRAINTS.md` flags this class of solution as unsustainable solo, and an easily-dismissed nag defeats its own purpose |
| Cron-like OS-level timer for the break reminder | Needs a separate scheduler (`launchd`) running independently of the Claude Code session, inconsistent with the existing all-hook-based `.claude/hooks/` design, harder to reverse |
| Do nothing further | Leaves the eye-strain mechanism (distinct from the clock block's late-night-fatigue mechanism) unaddressed, despite it having the best precedent of any option surveyed |

## Related ticket
HAB-251

## Date
2026-09-07
