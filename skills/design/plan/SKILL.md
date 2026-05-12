---
name: plan
effort: THOROUGH
reasoning: ARCHITECTURAL
output_style: DETAILED
description: Produce a structured implementation plan for a PM issue or milestone before any code is written. Fetches the issue, reads the codebase, breaks the work into implementation units, posts the plan as a PM comment, and waits for user approval. For large changes spanning multiple files, new domain entities, new dependencies, or architectural shifts.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

This skill produces plans, not code.

---

## Steps

### 1. Fetch the issue(s)

Call `mcp__linear__get_issue` for each relevant issue ID. If a milestone was named, call `mcp__linear__get_milestone` then `mcp__linear__list_issues` filtered to that milestone.

### 2. Read the codebase

Read `docs/ARCHITECTURE.md`, `docs/PRODUCT_SPEC.md`, and the source files most relevant to the work. Use search tools to locate existing models, repositories, view models, and UI files. Name real files and classes — do not invent hypothetical ones.

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

```
## Implementation plan — <short title>

### Issues
- HAB-XX: <title>

### New packages / dependencies
- <package>: <why needed>

### New models and classes
- `ClassName` in `lib/slices/<feature>/...` — <one-line purpose>

### Changes to existing classes
- `ClassName` (`lib/path/to/file.dart`): <what changes and why>

### UI changes
**iOS** (`lib/slices/<feature>/ui/ios/`):
- <change>

**Android** (`lib/slices/<feature>/ui/android/`):
- <change>

### Test strategy
- <what to test and how; name the test files>

### Implementation phases
1. **Phase 1 — <name>**: <what gets done; deliverable>
2. **Phase 2 — <name>**: <what gets done; deliverable>

### Work units
Each unit is one focused session. Keep units small enough to fit in a single PR.

| # | Unit | Issues | Files touched (approx) |
|---|------|--------|------------------------|
| 1 | <unit name> | HAB-XX | <files> |
```

### 4. Post the plan as a Linear comment

Call `mcp__linear__save_comment` on the primary issue with the full plan text so `implement` can reference it.

### 5. Present and wait

Show the plan to the user and wait for approval or adjustments. Do not proceed until the user explicitly approves.

### 6. Update ARCHITECTURE.md (after approval)

If the plan introduces new layers, directories, classes, or dependencies not already in `docs/ARCHITECTURE.md`, update that file now. Keep the existing structure — add to it, do not rewrite it.

---

## Constraints

- Do not write application code.
- Keep plans concrete: reference real files and classes from the current codebase.
- Never modify `CLAUDE.md` — that is the orchestrator's file.
- When updating `docs/ARCHITECTURE.md`, keep the existing structure (directory tree, layers table). Add to it; do not rewrite it.
