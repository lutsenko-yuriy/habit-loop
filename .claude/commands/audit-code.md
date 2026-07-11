Route this invocation to a subagent. **Do not execute the skill yourself.**

**Skill:** audit-code
**Tier:** THOROUGH + TACTICAL
**Model alias:** opus

Steps:
1. Read `skills/verify/audit/SKILL.md` using the Read tool.
2. Spawn an Agent with:
   - `model`: `"opus"`
   - `prompt`: full content of the skill file, followed by the arguments below.

**Arguments:**
$ARGUMENTS
