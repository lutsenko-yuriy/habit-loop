#!/bin/bash
# Test harness for break_reminder.sh — pipes representative UserPromptSubmit
# hook JSON payloads through the script and asserts on stdout. Uses
# BREAK_REMINDER_ENV_OVERRIDE to point at a scratch toggle file instead of the
# real per-machine .claude/break_reminder.env, BREAK_REMINDER_STATE_DIR_OVERRIDE
# to point at a scratch state directory instead of the real
# .claude/break_reminder_state/, and BREAK_REMINDER_NOW_OVERRIDE to fake the
# current epoch time instead of reading the real clock (deterministic elapsed-
# time assertions without sleeping in a test).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/break_reminder.sh"
TMP_ENV=$(mktemp)
TMP_STATE_DIR=$(mktemp -d)
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

check_silent() {
  local desc="$1" output="$2"
  if [ -z "$output" ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    echo "$output"
    fail=$((fail + 1))
  fi
}

reset_state() {
  rm -rf "$TMP_STATE_DIR"
  mkdir -p "$TMP_STATE_DIR"
}

run() {
  local session="$1" now="$2"
  echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$session\",\"prompt\":\"hi\"}" \
    | BREAK_REMINDER_ENV_OVERRIDE="$TMP_ENV" BREAK_REMINDER_STATE_DIR_OVERRIDE="$TMP_STATE_DIR" BREAK_REMINDER_NOW_OVERRIDE="$now" bash "$SCRIPT"
}

# 1. First prompt of a brand-new session -> starts the clock, no reminder yet.
printf '' > "$TMP_ENV"
reset_state
out=$(run "sess-1" 1000)
check_silent "first prompt of a session -> silent (clock starts)" "$out"

# 2. Second prompt, well under the default 20-minute interval -> still silent.
out=$(run "sess-1" 1500)
check_silent "prompt before interval elapses -> silent" "$out"

# 3. Prompt at/after the 20-minute mark -> reminder fires, mentions the 20-20-20 rule.
out=$(run "sess-1" $((1000 + 20 * 60)))
check "prompt at interval -> reminder fires" "20-20-20" "" "$out"
check "reminder is additionalContext for UserPromptSubmit" '"hookEventName": "UserPromptSubmit"' "" "$out"

# 4. Immediately after a reminder fires, the clock resets -> next prompt is silent again.
out=$(run "sess-1" $((1000 + 20 * 60 + 60)))
check_silent "prompt right after a reminder -> silent (clock reset)" "$out"

# 5. A different, independent session starts its own clock -> no cross-session leakage.
out=$(run "sess-2" $((1000 + 20 * 60 + 60)))
check_silent "a different session starts its own fresh clock" "$out"

# 6. Toggle off via env file -> always silent, even past the interval.
printf 'HL_BREAK_REMINDER=off\n' > "$TMP_ENV"
reset_state
run "sess-3" 1000 >/dev/null
out=$(run "sess-3" $((1000 + 20 * 60)))
check_silent "HL_BREAK_REMINDER=off -> always silent" "$out"

# 7. Custom interval via env file is honored.
printf 'HL_BREAK_REMINDER=on\nHL_BREAK_REMINDER_INTERVAL_MIN=5\n' > "$TMP_ENV"
reset_state
run "sess-4" 1000 >/dev/null
out=$(run "sess-4" $((1000 + 5 * 60)))
check "custom 5-minute interval fires early" "20-20-20" "" "$out"

# 8. Unhandled event type -> silent, exit 0 (defensive; this hook only wires to UserPromptSubmit).
printf '' > "$TMP_ENV"
out=$(echo '{"hook_event_name":"PreToolUse","session_id":"sess-5"}' \
  | BREAK_REMINDER_ENV_OVERRIDE="$TMP_ENV" BREAK_REMINDER_STATE_DIR_OVERRIDE="$TMP_STATE_DIR" BREAK_REMINDER_NOW_OVERRIDE=1000 bash "$SCRIPT")
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: unhandled event exits 0 silently"
  pass=$((pass + 1))
else
  echo "FAIL: unhandled event exits 0 silently (rc=$rc)"
  fail=$((fail + 1))
fi

# 9. Stale state files (older than a day) are pruned automatically, so a
#    solo dev never has to clean these up by hand.
reset_state
echo 1000 > "$TMP_STATE_DIR/stale-session"
touch -t "$(date -v-2d +%Y%m%d%H%M 2>/dev/null || date -d '2 days ago' +%Y%m%d%H%M)" "$TMP_STATE_DIR/stale-session"
run "sess-6" 100000 >/dev/null
if [ ! -e "$TMP_STATE_DIR/stale-session" ]; then
  echo "PASS: stale (>1 day) state files get pruned"
  pass=$((pass + 1))
else
  echo "FAIL: stale (>1 day) state files get pruned"
  fail=$((fail + 1))
fi

rm -rf "$TMP_ENV" "$TMP_STATE_DIR"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
