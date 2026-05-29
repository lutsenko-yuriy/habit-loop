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

### 1. Fetch open issues

Call `mcp__linear__list_issues` to list all open issues and group them by label:

- **Issues** — label `Bug` or `Tech Debt` — known problems already in the codebase
- **Remaining work** — label `Feature` or `Improvement` — planned work not yet started

### 2. Fetch the active milestone

Call `mcp__linear__list_milestones` with the project ID (`c3afdc26-d306-4f72-bdb3-de9b01060d0f`) to get all milestones and their completion percentage.

### 3. Produce the backlog summary

```
## Backlog — Habit Loop

### Active milestone: <name> (<X>% complete)

### Issues (bugs & tech debt)
- HAB-XX: <title> — <one-line description>

### Remaining work
- HAB-XX: <title> — <one-line description>

### Recently completed
- <version>: <summary of what shipped>
```

### 4. Ask and wait

End with: **"What goes into the next release?"** — do not proceed until the user answers.
