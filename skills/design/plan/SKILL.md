---
name: plan
effort: THOROUGH
reasoning: ARCHITECTURAL
output_style: DETAILED
description: Produce a structured implementation plan for a PM issue or milestone before any code is written. Fetches the issue, reads the codebase, breaks the work into implementation units, posts the plan as a PM comment, and waits for user approval. For large changes spanning multiple files, new domain entities, new dependencies, or architectural shifts.
---

@skills/shared/project-config.md

This skill produces plans, not code.

---

## Steps

### 1. Fetch the issue(s)

Call `mcp__linear__get_issue` for each relevant issue ID. If a milestone was named, call `mcp__linear__get_milestone` then `mcp__linear__list_issues` filtered to that milestone.

### 2. Read the codebase

Read the architecture and product spec files (paths from project config) and the source files most relevant to the work. Use search tools to locate existing models, repositories, view models, and UI files. Name real files and classes — do not invent hypothetical ones.

The vertical-slice structure to keep in mind:
- `lib/domain/` — shared pure domain models and repository interfaces
- `lib/slices/<feature>/domain/` — feature-local domain (if any)
- `lib/slices/<feature>/application/` — orchestration services and state
- `lib/slices/<feature>/data/` — repository implementations (SQLite)
- `lib/slices/<feature>/ui/generic/` — Riverpod notifiers and platform-agnostic helpers
- `lib/slices/<feature>/ui/ios/` — Cupertino widgets
- `lib/slices/<feature>/ui/android/` — Material widgets
- `lib/infrastructure/` — cross-cutting services (analytics, crashlytics, logging, notifications, persistence, remote config)

### 3. Produce the implementation plan

Use this format exactly. Omit a section entirely if it has no content.

**Feature toggle:** If the feature introduces new user-facing behaviour, include a Firebase Remote Config kill-switch flag (default `true`) in the plan so the feature can be disabled remotely without a release. Add the flag name and a `docs/FEATURE_TOGGLES.md` update to the relevant WU.

**Work unit rules (apply before writing the WU table):**
- WU0 is always the first unit: integration scenarios from `draft-scenarios`, committed as a `[test]`-tagged PR before any production code lands.
- Each subsequent WU must include an estimated LoC count. Target ≤ 300 LoC and ≤ 10 files. If a WU would exceed this, split it into two or more units.
- Each WU must list which scenarios it makes green. If a scenario requires UI that lands in a later WU, label it "filled in WU*N*" (not "made green WU*N*") so it is clear the scenario exists but cannot be driven until the UI is present.

@skills/design/plan/resources/plan-template.md

### 4. Post the plan as a PM comment

Call `mcp__linear__save_comment` on the primary issue with the full plan text so `implement` can reference it.

### 5. Present and wait

Show the plan to the user and wait for approval or adjustments. Do not proceed until the user explicitly approves.

### 6. Update ARCHITECTURE.md (after approval)

If the plan introduces new layers, directories, classes, or dependencies not already in the architecture doc (path from project config), update that file now. Keep the existing structure — add to it, do not rewrite it.

---

## Constraints

- Do not write application code.
- Keep plans concrete: reference real files and classes from the current codebase.
- Never modify `CLAUDE.md` — that is the orchestrator's file.
- When updating `docs/ARCHITECTURE.md`, keep the existing structure (directory tree, layers table). Add to it; do not rewrite it.
