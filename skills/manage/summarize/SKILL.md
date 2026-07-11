---
name: summarize
effort: RAPID
reasoning: MECHANICAL
context: linear
output_style: CONCISE
description: Present the current backlog at session start. Fetches open issues from the PM tool, shows the active milestone and completion percentage, groups work by label, splits it into a product-vs-process ticket count, and asks "What goes into the next release?" Invoke at the start of every session before any work begins.
---

@skills/shared/project-config.md

---

## Steps

### 1. Output the pre-fetched backlog

When routed via `skill_router.py` (`context: linear`), the backlog data is injected above this text between `=== PRE-FETCHED BACKLOG ===` sentinels. Copy that block verbatim — do not reformat, do not call any tools. **Known limitation:** the pre-fetched path does not classify product vs. process (step 1a below) — it only groups issues by the existing Bug/Tech Debt/Feature/Improvement Linear labels.

When running inside Claude Code (fallback path), list issues and milestones (PM mapping: **List issues**, **List milestones** — use the **Project ID** from the PM tool mapping) and produce the summary below:

```
## Backlog — Habit Loop

### Active milestone: <name> (<X>% complete)

**N product tickets · M process tickets pending.**

### Issues (bugs & tech debt)
- HAB-XX: <title> — <one-line description>

### Remaining work
- HAB-XX: <title> — <one-line description>
```

### 1a. Classify product vs. process (fallback path only)

For each ticket, read its title and description and classify it as:

- **Product** — a user-facing feature, bug fix, or app-facing improvement: anything that changes what the app does or how it behaves for an end user.
- **Process** — workflow, skill, tooling, CI, docs-audit, or research into how the team/agents work: anything that changes how the app gets built, not what it does.

Do not rely on Linear labels for this — the existing labels (Feature, Bug, Tech Debt, Improvement) don't distinguish product from process work; use judgment from each ticket's content. Compute N (product count) and M (process count) and fill in the summary line above, before the section breakdown. The goal is to make process debt visible at the point the release decision gets made, rather than letting it silently pile up across sessions until it's felt rather than seen (see HAB-154 debrief).

### 2. Ask and wait

End with: **"What goes into the next release? Pick an existing ticket or describe something new."** — do not proceed until the user answers.

If the user chooses to describe something new (says "something new", "new idea", "new feature", or otherwise indicates they want to start from scratch rather than pick an existing ticket), invoke the `brief` skill:

```
Invoke the brief skill
```

Do not jump to `plan` or `implement` for a new idea — always go through `brief` first so the idea is validated and a ticket is created before any planning begins.
