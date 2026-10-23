# PM Tool: GitHub Issues

All PM-tool-specific details live here. When porting to a different PM tool, replace this file — skill logic stays unchanged.

## Identity

| Setting | Value |
|---|---|
| Tool | GitHub Issues (via the `gh` CLI) |
| Repository | `lutsenko-yuriy/habit-loop` |
| Issue prefix | `HAB` |

Run every `gh` command with `-R lutsenko-yuriy/habit-loop` (or from inside the repo), so it never depends on the current directory.

## Ticket IDs: the HAB-N rule

IDs stay `HAB-N` everywhere (branches, notes, commits, CHANGELOG). The number tells you where the ticket lives (HAB-490):

- **N > 281** → GitHub issue **#N** (`gh issue view N`).
- **N ≤ 281** → the old **Linear archive**: read-only history. Never query it; the notes, ADRs and CHANGELOG already hold what matters.

## States are labels

| State | How it looks on GitHub |
|---|---|
| Backlog | open, no `state:*` label |
| Brief | open + `state:brief` (ADR-0008) |
| In Progress | open + `state:in-progress` (one ticket at a time) |
| In Review | open + `state:in-review` |
| In QA | open + `state:in-qa` |
| Done | closed as completed |
| Canceled | closed as not planned |

An open issue carries **at most one** `state:*` label, and a closed one none: a move removes the previous one in the same `gh issue edit` call, and closing removes it before `gh issue close`.

## Linking PRs to issues

Write `Closes HAB-N` in a PR body, never `Closes #N` (or `Fixes`/`Resolves #N`): GitHub would close the issue on merge, skipping In QA and `ship`'s state move. Use `Part of #N` when a clickable link is wanted.

## Type and priority labels

- Type: `feature`, `bug`, `tech-debt`, `improvement`.
- Priority: `priority:urgent`, `priority:high`, `priority:medium`, `priority:low`; no priority label means no priority.
- Due date: GitHub issues have none. A ticket that needs one carries `Due: YYYY-MM-DD` as the first line of its body (e.g. postmortems, `docs/workflows/POSTMORTEM.md`).

## Operation mapping

| Operation | Command | Notes |
|---|---|---|
| Fetch issue | `gh issue view N` | Add `--comments` when the step also needs the comments (e.g. a plan comment): one call instead of two. |
| List issues | `gh issue list --state open --limit 200 --json number,title,labels,body,updatedAt` | `--limit 200` is the project-wide default (gh's own default is 30); keep it unless a step needs only a handful of rows, and say so if a result hits it. Narrow `--json` to the fields the step needs; filter with `--label`, `--search "<words> in:title"`, or `--state all`. |
| Create issue | `gh issue create --title "..." --body-file <file> --label <type>[,priority:<p>]` | Add `--milestone "<title>"` when the ticket belongs to one. |
| Update issue | `gh issue edit N --title/--body-file/--add-label/--remove-label ...` | |
| Move issue to state | `gh issue edit N --remove-label <old state:*> --add-label state:<new>` | Backlog: only remove the old label. Done/Canceled: remove the current `state:*` label first (`gh issue edit N --remove-label state:in-qa`), then `gh issue close N --reason completed` (Done) or `--reason "not planned"` (Canceled) — a closed issue carries no `state:*` label. Reopen with `gh issue reopen N`. |
| List comments on issue | `gh issue view N --comments` | |
| Post comment on issue | `gh issue comment N --body-file <file>` | `--body "..."` for one-liners. |
| Fetch milestone | `gh api repos/lutsenko-yuriy/habit-loop/milestones/<number>` | |
| List milestones | `gh api "repos/lutsenko-yuriy/habit-loop/milestones?state=open"` | Progress = `closed_issues / (open_issues + closed_issues)`. |
| List issues in milestone | `gh issue list --milestone "<title>" --state all --json number,title,state,labels` | |

## Fetch once, reuse from the transcript

A single ticket's lifecycle can otherwise fetch the same issue six or seven times across `/analyze`, `/plan`, `/draft-scenarios`, `/implement`, and `/ship` (HAB-176).

Once an issue has been fetched in full earlier in the same session, later steps should read its details from the transcript instead of re-fetching, **unless**:
- The issue itself may have changed since the last fetch (e.g. after a state move this session performed). A new `/plan` comment is new content to read, not a reason to re-fetch the description.
- A field the current step needs was not captured by the earlier fetch (e.g. an earlier list returned only `title`/`labels`, but the current step needs the full body).
- `plan`'s comment was revised after approval later in the same session — confirm the transcript copy is the final approved version, not an earlier draft.

When in doubt, re-fetch. **A compacted transcript doesn't count as "already fetched"**: after compaction, treat the issue as not yet fetched.
