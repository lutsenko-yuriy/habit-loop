**Routing rule — only spawn when the target model differs from the current session model:**

- **Spawn to a specific alias** (`opus`, `sonnet`, `haiku`, or any other named Claude alias different from the session model) — use the Agent routing stub. This applies whether the target is more capable than the session model (e.g. spawning up to `opus`) or less capable (e.g. spawning down to `haiku` for a RAPID-tier skill) — the mechanism is the same either way: it is the only stub format that can target a named model other than the session's own.
- **Run locally** (same alias as session) — spawning adds cold-start overhead with no benefit; use the passthrough format.
- **Route to local model** (`lm-studio`) — use the script stub.

---

**Agent routing stub** (routing to a specific named Claude alias, whether more or less capable than the session model):
```markdown
Route this invocation to a subagent. **Do not execute the skill yourself.**

**Skill:** <name>
**Tier:** <EFFORT> + <REASONING>
**Model alias:** <alias>

Steps:
1. Read `skills/<path>/SKILL.md` using the Read tool.
2. Spawn an Agent with:
   - `model`: `"<alias>"`
   - `prompt`: full content of the skill file, followed by the arguments below.

**Arguments:**
$ARGUMENTS
```

**Passthrough stub** (target model == session model):
```markdown
@skills/<path>/SKILL.md

$ARGUMENTS
```

**Script stub** (`lm-studio` alias, or `needs_session_tools: true`):

_With arguments:_
```markdown
Run via Bash: `python3 scripts/skill_router skills/<path>/SKILL.md --args '$ARGUMENTS'`
If the script exits non-zero (LM Studio unavailable or model not loaded), fall back to reading `skills/<path>/SKILL.md` and executing it yourself.

$ARGUMENTS
```

_Without arguments:_
```markdown
Run via Bash: `python3 scripts/skill_router skills/<path>/SKILL.md`
If the script exits non-zero (LM Studio unavailable or model not loaded), fall back to reading `skills/<path>/SKILL.md` and executing it yourself.
```

> **Note:** Skills with `needs_session_tools: true` exit with code 2 immediately (no LM Studio call), forcing fallback to Claude Code. When assigning `lm-studio` to a tier, check if all skills at that tier have `needs_session_tools: true` — if so, a Claude alias would be more honest.

Only update stubs whose alias changed. If a stub is in the old passthrough format but its tier is now assigned a different Claude alias, rewrite it entirely to the Agent routing stub format — do not just insert an alias line.
