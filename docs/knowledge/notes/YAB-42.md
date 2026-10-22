---
bookmarks: [cross-project-sync, review-findings]
---

# YAB-42: /onboard: ask for analytics, logging and feature-flag tools; record "none" as a choice

YAB issue: https://github.com/lutsenko-yuriy/yuriys-agentic-boyz/issues/42, PR #43. This note lives in Habit Loop and not in YAB, because YAB's notes folder ships to every adopter. See YAB #45.

## Notes

### 2026-10-22

**Planning started against a stale nested copy of YAB (user correction)**

The session began in a copy of YAB nested inside Habit Loop, at `habit_loop/yuriys-agentic-boyz`, which was 19 commits behind `origin/main`. `/brief` read that copy, and so did `/plan` at first. The user asked "Which YAB are you going to modify?". That caught it before any code was written, and the planner was pointed at the real clone, `~/claude_projects/yuriys-agentic-boyz`. The nested copy was then deleted: it was clean, with no unpushed commits and no stashes.

**Scope reshaped in /brief: feature flags folded in, Noop code dropped**

The user asked whether `/onboard` should also set up a feature-flag tool. FEATURE step 1.4, `{{EXPERIMENT_TOOL}}` and checkup dimension 5 already assume one, so flags joined analytics and logging. Generating Noop code was dropped: "none" became a recorded choice, and a tool added later is the developer's own job.

## Debrief summary

### 2026-10-22

**What went well**
- `/brief` reshaped the scope as intended: feature flags were added, Noop code was dropped, and the change from the original proposal is listed under "Out of scope".
- Asking "which YAB?" caught a nested copy that was 19 commits behind before any code was written. The copy was deleted. This looks like a one-off, so no guard was added; revisit if it happens again.
- Overall: the user was happy with how the ticket was worked.

**What was hard or surprising**
- The `/audit` warning about a template test that checks the adopter-owned `docs/ANALYTICS_EVENTS.md` would have been caught by eye if the review loop had been watched more closely. Instead, a new ticket (YAB #44) was being briefed at the same time.
- YAB's own process artifacts (notes, CHANGELOG history) have no home inside YAB without leaking into the template. Tracked as YAB #45.

**What to change**
- Stay on the review loop instead of briefing a new ticket alongside it. This is a habit, with no workflow change.
