Route this invocation to a subagent. **Do not execute the skill yourself.**

**Skill:** review
**Tier:** FOCUSED + ARCHITECTURAL
**Model alias:** sonnet

Steps:
1. Read `skills/verify/review/SKILL.md` using the Read tool.
2. Spawn an Agent with:
   - `model`: `"sonnet"`
   - `prompt`: full content of the skill file, followed by the arguments below.

**Arguments:**
$ARGUMENTS
