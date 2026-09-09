#!/bin/bash
# UserPromptSubmit hook — fires a periodic (default every 20 minutes of active
# session time) break/eye-strain reminder, following the 20-20-20 rule
# precedent from HAB-251's research (see ADR-0007). Complements, and is
# deliberately independent of, nightly_block.sh's clock-window guard — that
# one addresses time-of-day fatigue; this one addresses eye-strain
# accumulated during a normal-hours session regardless of the clock.
#
# Unlike nightly_block.sh, this hook never blocks (exit 2) — it just injects
# additionalContext asking Claude to relay a one-line nudge to the user, the
# same mechanism session_start.sh uses to inject the session-start checklist.
#
# State: each session gets its own timestamp file under
# .claude/break_reminder_state/ (gitignored via the blanket .claude/* rule),
# keyed by the hook payload's session_id, tracking when the clock last reset
# (session start, or the last reminder). Stale (>1 day old) state files are
# pruned on every invocation so a solo dev never has to clean these up by
# hand (ticket constraint: no ongoing manual upkeep).
#
# Standing toggle: .claude/break_reminder.env (gitignored, per-machine) —
# mirrors nightly_block.env / alert.env. Takes effect on the very next prompt.
#
# Exit 0 always — this hook is a nudge, never a blocker.
#
# Test seams (see test_break_reminder.sh): BREAK_REMINDER_ENV_OVERRIDE points
# at a scratch toggle file, BREAK_REMINDER_STATE_DIR_OVERRIDE at a scratch
# state directory, BREAK_REMINDER_NOW_OVERRIDE fakes the current epoch time —
# same pattern as alert.sh's ALERT_ENV_OVERRIDE / FRONTMOST_APP_OVERRIDE.

PROJECT=/Users/yurich/claude_projects/habit_loop
ENV_FILE="${BREAK_REMINDER_ENV_OVERRIDE:-$PROJECT/.claude/break_reminder.env}"
STATE_DIR="${BREAK_REMINDER_STATE_DIR_OVERRIDE:-$PROJECT/.claude/break_reminder_state}"

input=$(cat)

event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null || true)
[ "$event" = "UserPromptSubmit" ] || exit 0

HL_BREAK_REMINDER=on
HL_BREAK_REMINDER_INTERVAL_MIN=20
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
[ "$HL_BREAK_REMINDER" = "on" ] || exit 0

# A hand-edited toggle file could set this to anything — fall back to the
# default rather than failing open into a garbled nudge on every prompt.
case "$HL_BREAK_REMINDER_INTERVAL_MIN" in
  ''|*[!0-9]*|0) HL_BREAK_REMINDER_INTERVAL_MIN=20 ;;
esac

session_id=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null || true)
[ -n "$session_id" ] || exit 0
# session_id is used verbatim as a filename below — reject anything that
# could escape STATE_DIR (path separators, leading dot) rather than risk
# writing outside it, where the staleness prune below can never find it.
case "$session_id" in
  */* | .*) exit 0 ;;
esac

mkdir -p "$STATE_DIR"

# Prune state files untouched for over a day — old sessions that never
# ended cleanly shouldn't accumulate forever.
find "$STATE_DIR" -type f -mtime +1 -delete 2>/dev/null || true

now="${BREAK_REMINDER_NOW_OVERRIDE:-$(date +%s)}"
interval_sec=$((HL_BREAK_REMINDER_INTERVAL_MIN * 60))
state_file="$STATE_DIR/$session_id"

if [ ! -f "$state_file" ]; then
  # First prompt of this session — start the clock, no reminder yet.
  echo "$now" > "$state_file"
  exit 0
fi

last=$(cat "$state_file" 2>/dev/null || echo "$now")
elapsed=$((now - last))

if [ "$elapsed" -lt "$interval_sec" ]; then
  exit 0
fi

# A gap of 3x the interval or more means the prompt-to-prompt gap was idle
# time away from the keyboard, not active session time — reset the clock
# silently rather than greeting a returning user with a false "it's been
# 20 minutes of active time" after a multi-hour lunch break.
away_threshold_sec=$((interval_sec * 3))
if [ "$elapsed" -ge "$away_threshold_sec" ]; then
  echo "$now" > "$state_file"
  exit 0
fi

# Interval elapsed, and the gap wasn't just idle time away — reset the clock
# and surface the nudge.
echo "$now" > "$state_file"

context="It's been about $HL_BREAK_REMINDER_INTERVAL_MIN minutes of active session time. Following the 20-20-20 rule: mention briefly to the user that it's a good moment for a short break — look at something 20 feet away for 20 seconds, or stretch."

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
