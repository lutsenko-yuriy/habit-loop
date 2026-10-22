---
bookmarks: [cross-project-sync]
---

# YAB-45: How to modify YAB without modifying YAB: a development project for the template

YAB issue: https://github.com/lutsenko-yuriy/yuriys-agentic-boyz/issues/45. The decision record is in the issue comment, and the follow-ups are YAB #46 (create the dev project) and #47 (CI generates a throwaway project). This note lives in Habit Loop only until #46 moves it into the dev project.

## Notes

### 2026-10-22

**Scoping before the survey**

Constraints specific to this ticket:
- one maintainer;
- the YAB repo stays a clean template;
- changes land as PRs to YAB;
- agent sessions are tied to one working directory;
- existing adopters must not be forced to change.

MoSCoW:
- **Must:** dev artifacts live outside the template, and the skills run on YAB work without hand-adapting.
- **Should:** move the YAB notes out of Habit Loop, and make the dev project YAB's first adopter.
- **Could:** versioning YAB's own releases.
- **Won't:** change adopters, or redesign `/onboard`.

The user approved this in one go.

**The survey confirmed the user's dev-project idea**

Every template tool except GitHub template repos keeps the template's contents in a subfolder or package, with the dev files at the root. "Use this template" copies the whole branch with no exclude, so moving YAB's template into a subfolder (option B) fails. A dev project with a sibling clone via `--add-dir` (option A) was chosen.

One catch: on a command name clash, the primary project's command wins. That made "the dev project runs behind YAB and syncs from tagged releases" the natural choice. You edit YAB's version of a skill while the last released version runs.

**Decisions (user)**

1. YAB's development tickets move to the dev repo, and YAB's Issues stay open for adopter feedback.
2. Two-repo sessions: the code PR goes to YAB, and the artifacts go to the dev repo.
3. The dev project runs behind YAB, syncing from tags.
4. YAB's CHANGELOG history moves to the dev project, and `apply`'s emptying step is removed.
5. YAB notes move out of Habit Loop whole, leaving a pointer in Habit Loop.

## Debrief summary

### 2026-10-22

**What went well**
- The flow (scoping, then a survey with cited sources, then decisions one at a time with a recommendation) ran smoothly, as the user put it: "brief works smooth as hell".
- The survey validated the user's own idea and surfaced the command-shadowing catch, which settled the sync question.

**What was hard or surprising**
- Nothing raised.

**What to change**
- Nothing raised.
