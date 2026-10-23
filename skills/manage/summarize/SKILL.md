---
name: summarize
effort: RAPID
reasoning: MECHANICAL
output_style: CONCISE
description: Present the current backlog at session start. Lists open issues from the PM tool (GitHub Issues via `gh`), classifies product vs. process, shows the active milestone (if any) and its completion percentage, groups work by type label and orders it by priority label, and asks "What goes into the next release?" Invoke at the start of every session before any work begins.
---

@skills/shared/project-config.md

---

## Steps

### 0. Survey `PLAN.local.md`, if present

Check for a `PLAN.local.md` file at the project root (gitignored — a personal, session-to-session scratch plan, not tracked in git). If it does not exist or is empty, skip to step 1.

If it exists and has content:
1. Read it and extract the listed tickets.
2. Check each listed ticket's current state against step 1's **List issues** result — run that call now (before continuing here) and reuse it in step 1; do not fetch twice. It returns open issues only, so a listed ticket that is missing from it is closed (Done or Canceled). Apply the HAB-N rule from the PM mapping: a listed `HAB-N` with N ≤ 281 is a Linear-archive ticket, so treat it as resolved and say so. Filter out every resolved ticket.
3. Present the surviving plan to the user (ticket IDs, titles, and any inline notes from the file) before the backlog summary below.
4. Ask: "Want to follow this plan, modify it, start a new plan alongside it, or set it aside and go with the regular backlog?" Wait for the answer before proceeding to step 1.

This catches stale-but-still-relevant intentions from a prior session before backlog review, and avoids re-drafting a ticket that's already listed here. See the HAB-173 debrief (2026-07-16): a `/brief` run created a duplicate of HAB-174 because nothing surfaced `PLAN.local.md`'s existing entry for the same idea.

### 0a. Flag overdue postmortem tickets

Any ticket titled `Postmortem: …` (see `docs/workflows/POSTMORTEM.md`) starts its body with a `Due: YYYY-MM-DD` line set at creation (GitHub issues have no due-date field). If such a ticket appears in the backlog with a `Due:` date in the past, flag it explicitly in the summary and ask whether to proceed with it now or drop it — do not let it silently blend into the rest of the backlog list.

### 1. Fetch and output the backlog

Fetch the data with the PM mapping's commands (labels and states: see the mapping):

- **List issues:** `gh issue list -R lutsenko-yuriy/habit-loop --state open --limit <mapping default> --json number,title,body,labels,milestone` (the `--limit` from the mapping's **List issues** row). Every open issue is in scope: Backlog (no `state:*` label) plus anything in Brief, In Progress, In Review or In QA.
- **List milestones:** `gh api "repos/lutsenko-yuriy/habit-loop/milestones?state=open"`. The active milestone is the open one with the earliest due date (or the lowest number when none has a due date); its progress is `closed_issues / (open_issues + closed_issues)`. With no open milestone, write `Active milestone: none`.

Ticket ID: `HAB-<number>`. One-line description: the first non-empty body line that is not a heading or a `Due:` line, cut to ~100 characters.

Group the issues by type label — `bug` and `tech-debt` under **Issues**, `feature`, `improvement` and unlabeled under **Remaining work**. Within each group, order by priority label (`priority:urgent`, `high`, `medium`, `low`, then no priority), then by issue number. Append the priority and any `state:*` label in brackets, e.g. `[high · in-qa]`; leave the brackets out when there is neither.

Produce the summary below:

```
## Backlog — Habit Loop

### Active milestone: <name> (<X>% complete)

**N product tickets · M process tickets pending.**

### Issues (bugs & tech debt)
- HAB-XX: <title> — <one-line description> [<priority> · <state>]

### Remaining work
- HAB-XX: <title> — <one-line description> [<priority> · <state>]
```

### 1a. Classify product vs. process

For each ticket, read its title and description and classify it as:

- **Product** — a user-facing feature, bug fix, or app-facing improvement: anything that changes what the app does or how it behaves for an end user.
- **Process** — workflow, skill, tooling, CI, docs-audit, or research into how the team/agents work: anything that changes how the app gets built, not what it does.

Do not rely on the type labels alone — `feature`, `bug`, `tech-debt` and `improvement` don't distinguish product from process work; use judgment from each ticket's content. Compute N (product count) and M (process count) and fill in the summary line above, before the section breakdown. The goal is to make process debt visible at the point the release decision gets made, rather than letting it silently pile up across sessions until it's felt rather than seen (see HAB-154 debrief).

### 2. Ask and wait

End with: **"What goes into the next release? Pick an existing ticket or describe something new."** — do not proceed until the user answers.

If the user chooses to describe something new (says "something new", "new idea", "new feature", or otherwise indicates they want to start from scratch rather than pick an existing ticket), invoke the `brief` skill:

```
Invoke the brief skill
```

Do not jump to `plan` or `implement` for a new idea — always go through `brief` first so the idea is validated and a ticket is created before any planning begins.
