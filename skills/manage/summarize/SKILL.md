---
name: summarize
effort: RAPID
reasoning: MECHANICAL
context: linear
output_style: CONCISE
description: Present the current backlog at session start. Fetches open issues from Linear, shows the active milestone and completion percentage, groups work by label, and asks "What goes into the next release?" Invoke at the start of every session before any work begins.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB** (e.g. `HAB-12`).

---

## Steps

### 1. Output the pre-fetched backlog

When routed via `skill_router.py` (`context: linear`), the backlog data is injected above this text between `=== PRE-FETCHED BACKLOG ===` sentinels. Copy that block verbatim — do not reformat, do not call any tools.

When running inside Claude Code (fallback path), call `mcp__linear__list_issues` and `mcp__linear__list_milestones` (project ID `c3afdc26-d306-4f72-bdb3-de9b01060d0f`) and produce the summary below:

```
## Backlog — Habit Loop

### Active milestone: <name> (<X>% complete)

### Issues (bugs & tech debt)
- HAB-XX: <title> — <one-line description>

### Remaining work
- HAB-XX: <title> — <one-line description>
```

### 2. Ask and wait

End with: **"What goes into the next release? Pick an existing ticket or describe something new."** — do not proceed until the user answers.

If the user chooses to describe something new (says "something new", "new idea", "new feature", or otherwise indicates they want to start from scratch rather than pick an existing ticket), invoke the `describe-feature` skill:

```
Invoke the describe-feature skill
```

Do not jump to `plan` or `implement` for a new idea — always go through `describe-feature` first so the idea is validated and a ticket is created before any planning begins.
