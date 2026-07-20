#!/bin/bash
# SessionStart hook — fires on session startup/resume (matcher "startup|resume"
# in .claude/settings.local.json) and injects the AGENTS.md "Session start"
# checklist (steps 1-4) as additionalContext so Claude runs it automatically
# instead of relying on the manual instruction alone. See HAB-186.
#
# What this script checks directly (cheap, deterministic):
#   - LINEAR_API_KEY / LM_API_TOKEN presence in the environment (CLAUDE.local.md)
#   - the active communication style from CLAUDE.local.md's
#     "## Active communication style" section (default DETAILED if absent)
# What it defers to Claude via additionalContext (needs live tool calls):
#   - confirming Linear MCP auth
#   - invoking the summarize skill
#   - running scripts/checkup/due.py --format=session

PROJECT=/Users/yurich/claude_projects/habit_loop
LOCAL_MD="$PROJECT/CLAUDE.local.md"

# Must consume stdin (hook input JSON) even though we don't need its fields.
cat >/dev/null

missing_env=""
[ -z "${LINEAR_API_KEY:-}" ] && missing_env="$missing_env LINEAR_API_KEY"
[ -z "${LM_API_TOKEN:-}" ] && missing_env="$missing_env LM_API_TOKEN"

style="DETAILED"
if [ -f "$LOCAL_MD" ]; then
  detected=$(awk '/^## Active communication style/{found=1; next} found && NF{print; exit}' "$LOCAL_MD")
  [ -n "$detected" ] && style="$detected"
fi

env_note=""
if [ -n "$missing_env" ]; then
  env_note="Note: the following env vars are not set in this shell:$missing_env — see CLAUDE.local.md for how to export them. "
fi

context=$(cat <<EOF
Run the AGENTS.md "Session start" checklist now, before responding to the user:
1. Confirm the Linear MCP is authenticated (mcp__linear__* tools available); if not, use /mcp to trigger OAuth. ${env_note}
2. Adopt the "$style" communication style detected from CLAUDE.local.md.
3. Invoke the summarize skill to present the current backlog from Linear.
4. Run scripts/checkup/due.py --format=session; if a tier is due, recommend /checkup alongside the backlog summary.
Then ask what goes into the next release, per AGENTS.md.
EOF
)

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
