Run via Bash: `python3 scripts/skill_router skills/manage/cleanup-firebase/SKILL.md --args '$ARGUMENTS'`
If the script exits non-zero (LM Studio unavailable or model not loaded), fall back by spawning an Agent — do not execute the skill directly in this session — with `model`: `"haiku"` and `prompt`: the full content of `skills/manage/cleanup-firebase/SKILL.md` (read via the Read tool), followed by the arguments below.

$ARGUMENTS
