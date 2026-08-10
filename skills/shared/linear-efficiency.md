# Linear Efficiency

Guidance for keeping `mcp__linear__*` interactions cheap, without sacrificing the accuracy of what gets read before an action is taken. See HAB-176.

## What actually costs tokens (measured, not guessed)

**Tool schemas are not the fixed cost they look like.** Claude Code's MCP tool search is on by default: only tool *names* (plus server instructions) load at session start — full JSON schemas load on demand, per tool, the first time it's called. The Linear MCP server exposes 53 `mcp__linear__*` tools; this repo's skills use 7 of them, but the other 46 cost only their name string (~400–700 tokens total for the whole set), not a full schema each. Don't budget for "N unused tools × schema size" — that number is not what's actually paid. If this stops being true (a Claude Code upgrade, a settings change that sets `alwaysLoad` on the `linear` server, or anything that disables tool search), the real fixed cost jumps back to the ~12–18k-token range measured before tool search existed — see `docs/knowledge/notes/HAB-176.md` for how that was confirmed live.

**The real, controllable cost is per-call payload and call count** — both scale with how carefully each skill step is written.

## Minimum-viable field sets

`mcp__linear__list_issues` and `mcp__linear__list_projects` accept a `fields` parameter; the default response (no `fields`) returns every field, including a truncated description, URL, git branch name, SLA/timestamp fields, and denormalized `project`/`team` names repeated on every row. Measured on a 5-issue project-filtered query: default response ~5,600 chars (~1,400 tokens, ~280 tok/issue) vs. `fields: ["title","status","labels"]` ~640 chars (~160 tokens, ~32 tok/issue) — an ~89% reduction for that shape of query.

Request only what the calling step actually needs:

| Step needs… | `fields` |
|---|---|
| Just filtering/counting by status | `["status", "statusType"]` |
| Backlog summary rows (title + status + label grouping) | `["title", "status", "statusType", "labels"]` |
| Priority-sorted triage | `["title", "status", "priority"]` |

`mcp__linear__get_issue` has **no `fields` parameter** — its payload (full description, comments, state history) is irreducible through the MCP. The only lever on `get_issue` cost is calling it less (see "Fetch once, reuse" below), not trimming what it returns. When a step genuinely needs the full description (e.g. `/plan`, `/brief`, `/audit-code` acting on ticket content), call it in full — this guidance is about cutting incidental re-fetches, never about reading less than what's needed at the point it's needed.

## Other defaults worth overriding

- `list_issues`/`list_projects` default `limit` is 50 — pass an explicit, smaller `limit` when a step only needs a handful of rows (e.g. checking one specific ticket's state).
- `list_issues` defaults `includeArchived: true` — pass `includeArchived: false` unless the step specifically needs archived tickets (e.g. `/cleanup-firebase`-style historical audits).

## Fetch once, reuse from the transcript

A single ticket's lifecycle can otherwise run `get_issue` six or seven times across `/analyze`, `/plan`, `/draft-scenarios`, `/implement`, and `/ship` — each a full-description, full-comment-history fetch of content that usually hasn't changed between those steps.

Once an issue has been fetched in full earlier in the same session, later steps should read its details from the transcript instead of re-fetching, **unless**:
- The issue may have changed since the last fetch (e.g. after a state transition this session performed, like `/plan` posting a comment or `/ship` moving the ticket to In QA), or
- A field the current step needs was not captured by the earlier fetch (e.g. an earlier step only listed `title`/`status`, but the current step needs the full description).

When in doubt, re-fetch — this convention trades a rare redundant call for the far more common case of not re-reading content that's already in context. It never trades away the accuracy of what a step acts on.

## Known redundant round-trips (fixed as part of HAB-176)

- `summarize`'s per-ticket `get_issue` loop, used only to recover `status` — replaced by `fields`-scoped `list_issues` (WU2).
- `ship`'s two adjacent "fetch the issue" preconditions — collapsed into one fetch (WU2).
- `draft-scenarios`/`implement` pairing `get_issue` with a separate `list_comments` where the plan comment was the only thing needed — addressed via the fetch-once convention (WU3).
