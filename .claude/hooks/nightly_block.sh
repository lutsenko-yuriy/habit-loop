#!/bin/bash
# UserPromptSubmit hook — hard-blocks any new prompt between 23:00 and 07:59
# local time (HAB-247 debrief, 2026-08-24). The user asked for this after
# noticing late-night sessions correlate with lower attentiveness/thoroughness
# on their own part — a self-imposed working-hours guard, not a code-quality
# mechanism.
#
# Deliberately no in-the-moment override (the user's explicit choice: "hard
# block... forces the habit"). To actually disable it, flip the toggle file
# below — mirrors alert.sh's .claude/alert.env pattern rather than adding a
# per-message bypass, which would defeat the point.
#
# Exit 2 = block the prompt; stderr is shown to the user (not sent to the model).
# Exit 0 = allow.

PROJECT=/Users/yurich/claude_projects/habit_loop
TOGGLE_FILE="${NIGHTLY_BLOCK_ENV_OVERRIDE:-$PROJECT/.claude/nightly_block.env}"

# Must consume stdin (hook input JSON) — unused here, but every other hook in
# this repo drains stdin before exiting, and leaving it unread has caused
# broken-pipe noise from the harness side in the past.
cat >/dev/null

HL_NIGHTLY_BLOCK=on
[ -f "$TOGGLE_FILE" ] && source "$TOGGLE_FILE"
[ "$HL_NIGHTLY_BLOCK" = "on" ] || exit 0

hour="${NIGHTLY_BLOCK_HOUR_OVERRIDE:-$(date +%H)}"
# Window: 23:00–07:59 (hour 23, or hour 00–07).
if [ "$hour" -ge 23 ] || [ "$hour" -lt 8 ]; then
  echo "BLOCKED: it's outside your 8am–11pm working hours. This session won't act on new requests until 8am. To disable this guard, set HL_NIGHTLY_BLOCK=off in .claude/nightly_block.env." >&2
  exit 2
fi

exit 0
