# ADR-0008 — add a "Brief" Linear ticket state before In Progress; reject a separate "Debrief" state

## Status
`accepted`

## Context
HAB-254's debrief (2026-08-28) noted that a growing share of work is asynchronous and
spans several days (agent-driven implementation, background CI waits, review loops), and
that the current state set — Backlog → In Progress → In Review → In QA → Done — doesn't
distinguish "being scoped/briefed" or "being debriefed" from the surrounding states,
making it harder to see at a glance where a multi-day ticket actually sits. HAB-255
researched whether adding explicit "Brief" and "Debrief" states addresses this.

Findings:
- The team's actual Linear state set has no native `Triage`-type state in use, even
  though Linear ships one specifically for pre-work scoping — a real, native precedent
  for a "Brief"-shaped state that this project simply hasn't adopted yet.
- No comparable precedent was found for a post-work retrospective as a *board column* —
  Scrum/Kanban retros live at sprint/cycle level, not per-ticket, and GitHub Projects
  custom-status setups rarely add one either.
- Empirically, `/debrief` is fast and synchronous in this project's own recent practice
  (e.g. HAB-268, 2026-09-09: debrief ran in one exchange, immediately followed by
  `/ship`) — it is not the part of a ticket's lifecycle that spans multiple days. The
  parts that actually span days are already visible: **In Review** (PR open, CI/reviewer
  wait) and **In QA** (merged, device-testing wait).
- No MCP tool exposes creating or editing Linear team workflow states — adding either
  state is a manual Settings → Workflow step outside agent tooling, which raises the bar
  for adopting a state that doesn't clearly earn its keep.

## Decision
Add a **"Brief"** state (Triage-type, sitting before **Todo**/**In Progress**) to the
Habit Loop team's Linear workflow, for tickets undergoing `/brief`, `/analyze`, `/plan`,
or `/draft-scenarios` before implementation code begins. Do **not** add a "Debrief"
state — `/debrief` stays where it already sits in `docs/workflows/FEATURE.md`/
`RESEARCH.md` (immediately before `/ship`, within the ticket's existing In
Progress/In Review state), since it doesn't address the multi-day-visibility problem
this ticket was opened to solve, and has no supporting precedent.

The "Brief" state is manually configured in Linear (Settings → Workflow) — not something
this decision automates. Once added, a ticket moves Backlog → **Brief** → Todo/In
Progress → In Review → In QA → Done, with the pre-implementation planning gates from
`docs/workflows/FEATURE.md` step 1 mapped onto the Brief state.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Adopt both Brief and Debrief | Debrief has no board-state precedent and doesn't address the actual multi-day-wait pain point (which is In Review/In QA, not the retro step) — would add workflow-doc and Linear-config complexity for no measurable benefit. |
| Adopt neither | Rejected in favor of Brief: the pre-implementation scoping gates (`/brief`/`/analyze`/`/plan`/`/draft-scenarios`) genuinely can span multiple days for under-specified tickets and are currently invisible under Backlog/In Progress — this is a real, distinct gap Triage-type states exist to solve. |

## Related ticket
HAB-255

## Date
2026-09-09
