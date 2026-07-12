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
# Both channels are also suppressed by default when a terminal-class app is
# frontmost (HL_ALERT_SUPPRESS_FOCUSED) — if a terminal is already focused,
# assume it's this session and skip the alert. This is a coarse "any
# terminal" check, not a verification that it's specifically this session's
# window — acceptable per HAB-162 for single-session use.
#
# HL_ALERT_DRY_RUN=1 prints "NOTIFY: ..." / "SPEAK: ..." lines instead of
# firing real notifications/speech, for testing (see test_alert.sh).
# ALERT_ENV_OVERRIDE lets tests point at a scratch toggle file.
# FRONTMOST_APP_OVERRIDE lets tests fake the frontmost-app check.

PROJECT=/Users/yurich/claude_projects/habit_loop
ALERT_ENV="${ALERT_ENV_OVERRIDE:-$PROJECT/.claude/alert.env}"
TERMINAL_APPS="Terminal iTerm2 iTerm Ghostty Alacritty kitty WezTerm Hyper Warp"

# Must consume stdin (hook input JSON).
input=$(cat)

# Gate 1: bail out early for any event this script doesn't act on, before
# paying for the frontmost-app check below.
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null || true)
case "$event" in
  Notification | Stop) ;;
  *) exit 0 ;;
esac

# Defaults; overridden by the per-machine toggle file if present.
HL_ALERT_NOTIFY=on
HL_ALERT_SPEAK=on
HL_ALERT_SUPPRESS_FOCUSED=on
[ -f "$ALERT_ENV" ] && source "$ALERT_ENV"

# Gate 2: skip both channels if a terminal is already frontmost — no need to
# build the alert body if we're not going to fire it.
if [ "$HL_ALERT_SUPPRESS_FOCUSED" = "on" ]; then
  frontmost="${FRONTMOST_APP_OVERRIDE-}"
  if [ -z "${FRONTMOST_APP_OVERRIDE+set}" ]; then
    frontmost=$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)
  fi
  for app in $TERMINAL_APPS; do
    [ "$frontmost" = "$app" ] && exit 0
  done
fi

# Past both gates — build what the alert will say.
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
esac

if [ "${HL_ALERT_DRY_RUN:-0}" = "1" ]; then
  [ "$HL_ALERT_NOTIFY" = "on" ] && echo "NOTIFY: $title - $body"
  [ "$HL_ALERT_SPEAK" = "on" ] && echo "SPEAK: $body"
  exit 0
fi

if [ "$HL_ALERT_NOTIFY" = "on" ]; then
  osascript -e 'on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
  end run' "$title" "$body" >/dev/null 2>&1
fi

if [ "$HL_ALERT_SPEAK" = "on" ]; then
  say "$body" >/dev/null 2>&1
fi

exit 0
