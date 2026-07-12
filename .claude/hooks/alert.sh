#!/bin/bash
# Notification/Stop hook — fires when a Claude Code session is blocked waiting
# on input (Notification: permission prompt or idle >60s) or has finished
# responding and stopped (Stop: a "soft blocker" — nothing is formally
# required, but staying idle doesn't help either). See HAB-162.
#
# Two independently toggleable channels: a macOS notification (osascript) and
# spoken alert (say). Both on by default. Toggles live in a dedicated,
# gitignored per-machine file (.claude/alert.env — NOT .claude/hooks/, which is
# tracked) so flipping a toggle takes effect on the very next alert without
# restarting the Claude Code session.
#
# HL_ALERT_DRY_RUN=1 prints "NOTIFY: ..." / "SPEAK: ..." lines instead of
# firing real notifications/speech, for testing (see test_alert.sh).
# ALERT_ENV_OVERRIDE lets tests point at a scratch toggle file.

PROJECT=/Users/yurich/claude_projects/habit_loop
ALERT_ENV="${ALERT_ENV_OVERRIDE:-$PROJECT/.claude/alert.env}"

# Must consume stdin (hook input JSON).
input=$(cat)

event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || true)
repo=$(basename "${cwd:-$PWD}")
title="Claude Code — $repo"

case "$event" in
  Notification)
    body=$(printf '%s' "$input" | jq -r '.message // ""' 2>/dev/null || true)
    [ -n "$body" ] || body="Claude needs your input"
    ;;
  Stop)
    body="Session in $repo stopped and is waiting"
    ;;
  *)
    exit 0
    ;;
esac

# Defaults; overridden by the per-machine toggle file if present.
HL_ALERT_NOTIFY=on
HL_ALERT_SPEAK=on
[ -f "$ALERT_ENV" ] && source "$ALERT_ENV"

if [ "$HL_ALERT_NOTIFY" = "on" ]; then
  if [ "${HL_ALERT_DRY_RUN:-0}" = "1" ]; then
    echo "NOTIFY: $title - $body"
  else
    osascript -e 'on run argv
      display notification (item 2 of argv) with title (item 1 of argv)
    end run' "$title" "$body" >/dev/null 2>&1
  fi
fi

if [ "$HL_ALERT_SPEAK" = "on" ]; then
  if [ "${HL_ALERT_DRY_RUN:-0}" = "1" ]; then
    echo "SPEAK: $body"
  else
    say "$body" >/dev/null 2>&1
  fi
fi

exit 0
