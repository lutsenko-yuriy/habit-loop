#!/bin/bash
# Test harness for alert.sh — pipes representative hook JSON payloads through
# the script in dry-run mode (HL_ALERT_DRY_RUN=1) and asserts on stdout instead
# of firing real notifications/speech. Uses ALERT_ENV_OVERRIDE to point at a
# scratch toggle file instead of the real per-machine .claude/alert.env.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERT="$HERE/alert.sh"
TMP_ENV=$(mktemp)
pass=0
fail=0

check() {
  local desc="$1" expected="$2" unexpected="$3" output="$4"
  if echo "$output" | grep -qF "$expected" && { [ -z "$unexpected" ] || ! echo "$output" | grep -qF "$unexpected"; }; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    echo "  --- output ---"
    echo "$output" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
}

rm -f "$TMP_ENV"

# 1. Notification event, no alert.env present -> both channels fire by default,
#    using the hook's own message verbatim.
out=$(echo '{"hook_event_name":"Notification","message":"Claude needs permission to run rm","cwd":"/tmp/some-repo"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
check "notification: notify channel fires by default" "NOTIFY: Claude Code — some-repo - Claude needs permission to run rm" "" "$out"
check "notification: speak channel fires by default" "SPEAK: Claude needs permission to run rm" "" "$out"

# 2. Stop event -> composed context-specific message (no message field on Stop payloads).
out=$(echo '{"hook_event_name":"Stop","cwd":"/tmp/habit_loop"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
check "stop: composed context-specific message" "Session in habit_loop stopped and is waiting" "" "$out"

# 3. Notify disabled via toggle file -> only SPEAK fires.
printf 'HL_ALERT_NOTIFY=off\nHL_ALERT_SPEAK=on\n' > "$TMP_ENV"
out=$(echo '{"hook_event_name":"Notification","message":"test msg","cwd":"/tmp/x"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
check "notify=off suppresses NOTIFY" "SPEAK: test msg" "NOTIFY:" "$out"

# 4. Speak disabled via toggle file -> only NOTIFY fires.
printf 'HL_ALERT_NOTIFY=on\nHL_ALERT_SPEAK=off\n' > "$TMP_ENV"
out=$(echo '{"hook_event_name":"Notification","message":"test msg","cwd":"/tmp/x"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
check "speak=off suppresses SPEAK" "NOTIFY:" "SPEAK:" "$out"

# 5. Both disabled -> silent.
printf 'HL_ALERT_NOTIFY=off\nHL_ALERT_SPEAK=off\n' > "$TMP_ENV"
out=$(echo '{"hook_event_name":"Notification","message":"test msg","cwd":"/tmp/x"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
if [ -z "$out" ]; then
  echo "PASS: both off -> silent"
  pass=$((pass + 1))
else
  echo "FAIL: both off -> silent"
  echo "$out"
  fail=$((fail + 1))
fi

# 6. Unhandled event type -> silent, exit 0 (script only reacts to Notification/Stop).
unhandled_out=$(echo '{"hook_event_name":"PreToolUse"}' \
  | HL_ALERT_DRY_RUN=1 ALERT_ENV_OVERRIDE="$TMP_ENV" bash "$ALERT")
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$unhandled_out" ]; then
  echo "PASS: unhandled event exits 0 silently"
  pass=$((pass + 1))
else
  echo "FAIL: unhandled event exits 0 silently (rc=$rc)"
  fail=$((fail + 1))
fi

rm -f "$TMP_ENV"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
