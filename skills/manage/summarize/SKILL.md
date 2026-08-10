---
name: summarize
effort: RAPID
reasoning: MECHANICAL
context: linear
output_style: CONCISE
description: Present the current backlog at session start. Fetches open issues from the PM tool — via the pre-fetched `skill_router` path, or a live fallback (with product-vs-process classification) if that path is unavailable — shows the active milestone and completion percentage, groups work by label, and asks "What goes into the next release?" Invoke at the start of every session before any work begins.
---

@skills/shared/project-config.md

---

## Steps

### 0. Survey `PLAN.local.md`, if present

Check for a `PLAN.local.md` file at the project root (gitignored — a personal, session-to-session scratch plan, not tracked in git). If it does not exist or is empty, skip to step 1.

If it exists and has content:
1. Read it and extract the listed tickets.
2. Check each listed ticket's current state against the pre-fetched backlog (the `=== PRE-FETCHED BACKLOG ===` block described in step 1 — every issue in it is already state-filtered to non-`Done`/non-`Canceled`, so a listed ticket simply not present has either resolved or fallen outside the block's 50-most-recently-updated window). If that block is unavailable, run step 1's live-fallback **List issues** call now (before continuing here) — its `fields` already include `statusType`, so this same call covers both this check and step 1's backlog output; do not fetch twice. Filter out any already `Done`, `Canceled`, or otherwise resolved.
3. Present the surviving plan to the user (ticket IDs, titles, and any inline notes from the file) before the backlog summary below.
4. Ask: "Want to follow this plan, modify it, start a new plan alongside it, or set it aside and go with the regular backlog?" Wait for the answer before proceeding to step 1.

This catches stale-but-still-relevant intentions from a prior session before backlog review, and avoids re-drafting a ticket that's already listed here. See the HAB-173 debrief (2026-07-16): a `/brief` run created a duplicate of HAB-174 because nothing surfaced `PLAN.local.md`'s existing entry for the same idea.

### 1. Output the pre-fetched backlog

Routed via `skill_router.py` (`context: linear`) — the backlog data is injected above this text between `=== PRE-FETCHED BACKLOG ===` sentinels. Copy that block verbatim — do not reformat, do not call any tools. **Known limitation:** the pre-fetched path does not classify product vs. process (step 1a below) — it only groups issues by the existing Bug/Tech Debt/Feature/Improvement Linear labels.

**Live MCP fallback (restored, HAB-176):** if the sentinel block is missing — the router script failed (e.g. `LM_API_TOKEN`/`LINEAR_API_KEY` unset, LM Studio not running, or a `skill_router` bug — see `CLAUDE.local.md`) and this skill is running via the Agent fallback in `.claude/commands/summarize.md` — do not block on the user fixing it first. Tell the user in one line that the pre-fetch is unavailable and this run is using the slower live path. Then:

- **List issues** (PM mapping) with `fields: ["title", "description", "status", "statusType", "labels"]` and `includeArchived: false`. **Do not pass `state`** — the tool's `state` parameter accepts only a single state/type/ID with no negation, so it cannot express "not Done/Canceled" the way the pre-fetched block's GraphQL query does; filter client-side on `statusType` instead. Also do not filter by project — the pre-fetched block's own query has no project filter either (whole-workspace, 50 most-recently-updated), so this intentionally does not "match" a project-scoped fetch.
- **List milestones** (PM mapping) using the **Project ID** from the PM tool mapping — milestones, unlike issues, are project-scoped in both paths.

Produce the summary below:

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

Do not rely on Linear labels alone — the existing labels (Feature, Bug, Tech Debt, Improvement) don't distinguish product from process work; use judgment from each ticket's content. Compute N (product count) and M (process count) and fill in the summary line above, before the section breakdown. The goal is to make process debt visible at the point the release decision gets made, rather than letting it silently pile up across sessions until it's felt rather than seen (see HAB-154 debrief).

### 2. Ask and wait

End with: **"What goes into the next release? Pick an existing ticket or describe something new."** — do not proceed until the user answers.

If the user chooses to describe something new (says "something new", "new idea", "new feature", or otherwise indicates they want to start from scratch rather than pick an existing ticket), invoke the `brief` skill:

```
Invoke the brief skill
```

Do not jump to `plan` or `implement` for a new idea — always go through `brief` first so the idea is validated and a ticket is created before any planning begins.
