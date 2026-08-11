Route this invocation to a subagent. **Do not execute the skill yourself.**

**Skill:** draft-release-notes
**Tier:** RAPID + TACTICAL
**Model alias:** haiku

Steps:
1. Read `skills/manage/draft-release-notes/SKILL.md` using the Read tool.
2. Spawn an Agent with:
   - `model`: `"haiku"`
   - `prompt`: full content of the skill file, followed by the arguments below.

**Arguments:**
$ARGUMENTS
