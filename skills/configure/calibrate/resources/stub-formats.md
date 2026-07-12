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

The fallback path must **never** run at the session's own uncontrolled model — it always spawns an Agent at a named, cheap fallback alias, exactly like the Agent routing stub above. This keeps the fallback's cost ceiling bounded to the skill's own tier instead of whatever model the orchestrating session happens to be.

**Fallback alias rule:** derive it from the skill's own Effort Tier, using the Active mapping in `docs/MODEL_TIERS.md`:
- **FOCUSED**-tier skills → `sonnet` (the established alias for FOCUSED work elsewhere, e.g. `brief`/`analyze`/`experiment`) — a quality hedge for tiers doing real code or judgment work, not just mechanical transforms.
- **RAPID**-tier skills → `haiku` (the cheapest named alias) — these are already meant to be fast/cheap, so the fallback should match that intent exactly.
- **THOROUGH**-tier skills should not use the script stub at all (see `> Note:` below).

_With arguments:_
```markdown
Run via Bash: `python3 scripts/skill_router skills/<path>/SKILL.md --args '$ARGUMENTS'`
If the script exits non-zero (LM Studio unavailable or model not loaded), fall back by spawning an Agent — do not execute the skill directly in this session — with `model`: `"<fallback-alias>"` and `prompt`: the full content of `skills/<path>/SKILL.md` (read via the Read tool), followed by the arguments below.

$ARGUMENTS
```

_Without arguments:_
```markdown
Run via Bash: `python3 scripts/skill_router skills/<path>/SKILL.md`
If the script exits non-zero (LM Studio unavailable or model not loaded), fall back by spawning an Agent — do not execute the skill directly in this session — with `model`: `"<fallback-alias>"` and `prompt`: the full content of `skills/<path>/SKILL.md` (read via the Read tool).
```

> **Note:** Skills with `needs_session_tools: true` exit with code 2 immediately (no LM Studio call), forcing the fallback on every invocation. When assigning `lm-studio` to a tier, check if all skills at that tier have `needs_session_tools: true` — if so, a Claude alias would be more honest as the *primary* route, since the script stub is only ever exercising the fallback path in practice.

Only update stubs whose alias or fallback alias changed. If a stub is in the old passthrough format but its tier is now assigned a different Claude alias, rewrite it entirely to the Agent routing stub format — do not just insert an alias line.
