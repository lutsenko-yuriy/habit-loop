# Multi-Agent Workflow

This document describes the planned multi-agent setup for Habit Loop development.
It is the source of truth for which agents exist, what they do, and what still needs to be built.

## Overview

Four agents collaborate to take work from a Linear ticket to a merged PR:

```
User
 └→ Product Owner  — manages Linear, keeps docs in sync
 └→ Tech Lead      — plans implementation, owns architecture
     └→ Developer  — writes code, creates PRs, links tickets
         └→ Code Reviewer  — reviews each PR before merge
```

---

## Agents

### Product Owner
**File:** `.claude/agents/product-owner.md`
**Model:** `claude-sonnet-4-6`

Responsibilities:
- At session start: query Linear for open issues and present the prioritised backlog to the user instead of reading BACKLOG.md statically
- Triage new bugs, features, and tech debt described by the user → create properly labelled Linear issues
- Release planning: group issues into Linear milestones/cycles; confirm scope with the user before work begins
- After a PR is merged: close the relevant Linear issue(s), close the milestone if complete, regenerate BACKLOG.md (open issues) and CHANGELOG.md (completed milestones) from Linear data

### Tech Lead
**File:** `.claude/agents/tech-lead.md` *(to be created)*
**Model:** `claude-opus-4-6`

Responsibilities:
- Read the prioritised backlog from Linear (via Product Owner output or directly)
- Produce implementation plans per the CLAUDE.md format (new deps, models, classes, UI changes, test strategy, ordered phases)
- Break a milestone's issues into work units small enough for a single Developer agent session
- Update `docs/ARCHITECTURE.md` when the plan changes the code structure
- Review Developer agent PRs at an architectural level before requesting human/code-reviewer review

### Developer
**File:** `.claude/agents/developer.md` *(to be created)*
**Model:** `claude-sonnet-4-6`

Responsibilities:
- Pick up one work unit from the Tech Lead's plan
- Follow TDD: write failing tests → implement → refactor → `flutter test` + `flutter analyze`
- Create feature branch, commit, push, open PR
- Update the Linear issue with the PR link and move it to `In Review`
- Invoke the Code Reviewer agent on the PR

### Code Reviewer
**File:** `.claude/agents/code-reviewer.md` *(already exists)*
**Model:** `claude-sonnet-4-6`

Responsibilities:
- Review PRs for runtime risks, launch failures, migration issues, and platform-specific edge cases
- Leave inline comments on the PR via GitHub CLI
- Produce a structured summary (Critical / Warning / Suggestion / Looks good)

---

## Linear workspace

**MCP config:** `.mcp.json` (project-scoped, committed to repo)
**MCP server:** `https://mcp.linear.app/mcp`

Linear workspace (configured):
- Team: `Habit Loop` (abbreviation `HAB`)
- Workflow states: `Backlog → Todo → In Progress → In Review → Done` (cancelled: `Canceled`, `Duplicate`)
- Labels: `Feature`, `Improvement`, `Bug`, `Tech Debt`
- Milestones v0.0.1–v0.5.0 created; one milestone per app version going forward

---

## Implementation status

| Phase | What | Status |
|---|---|---|
| 1 | Linear MCP setup + workspace creation | Done — MCP connected, workspace configured |
| 2 | Product Owner agent + migrate BACKLOG/CHANGELOG to Linear | **Done** — agent at `.claude/agents/product-owner.md`; all issues (IUR-10–IUR-17) and milestones (v0.0.1–v0.5.0) in Linear; CLAUDE.md updated |
| 3 | Tech Lead agent | Pending |
| 4 | Developer agent | Pending |
| 5 | Update CLAUDE.md to orchestrate all agents | Pending |

### Next actions (start of next session)
1. Build the Tech Lead agent (`.claude/agents/tech-lead.md`)
2. Build the Developer agent (`.claude/agents/developer.md`)
3. Update CLAUDE.md workflow to invoke Tech Lead for large changes and Developer for implementation
