# Research Workflow

Use this workflow for research-only tickets (no production code, no PR beyond the debrief commit). For features use `docs/FEATURE_WORKFLOW.md`; for bugs/CI use `docs/TROUBLESHOOT_WORKFLOW.md`.

> **Note:** The Linear organisation and documentation structure for research outputs will be defined when HAB-146 ships. Update this file at that point.

@skills/shared/decision-guidelines.md

## Steps

0. **Scope the ticket before surveying.** Two passes, both ticket-specific (not covered by the general `docs/CONSTRAINTS.md`):
   - **Ticket-specific constraints.** List constraints unique to this ticket — including non-functional ones (existing infra, timing, ownership) — beyond the standing project constraints. Surfacing these early can invalidate the premise of the research before survey effort is spent.
   - **MoSCoW the requirements.** Sort the ticket's research goals into Must/Should/Could/Won't. Survey and evaluate Musts first — a goal that turns out to be Could-have may already be satisfied by the status quo.

1. **Survey existing alternatives first.** Before forming opinions, document what comparable apps or tools already do. This grounds proposals in real precedent and surfaces patterns that are otherwise easy to miss.

2. **Evaluate trade-offs against `docs/CONSTRAINTS.md`.** For each option, assess how well it fits the standing constraints, rank options by fit, and call out explicitly what could go wrong with each given current constraints (e.g. "requires ongoing human review — unsustainable solo").

3. **Capture findings mid-session** with `/note HAB-XX: <observation>` as conclusions emerge — do not batch everything to the end.

4. **Debrief and close** with `/debrief HAB-XX` when all research questions are answered.
