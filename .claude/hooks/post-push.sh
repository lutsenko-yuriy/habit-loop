#!/bin/bash
# PostToolUse hook — fires after every Bash tool call.
# Acts only when the command was a git push.

# Must consume stdin (hook input JSON)
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

# Skip if this wasn't a git push
printf '%s' "$cmd" | grep -qE 'git.*push' || exit 0

FLUTTER=/opt/homebrew/Caskroom/flutter/3.41.5/flutter/bin/flutter
ANDROID_EMU=/Users/yurich/Library/Android/sdk/emulator/emulator
ADB=/Users/yurich/Library/Android/sdk/platform-tools/adb
PROJECT=/Users/yurich/claude_projects/habit_loop
LOG=/tmp/habit-loop-post-push.log

echo "=== post-push hook: $(date) ===" >> "$LOG"
echo "command: $cmd" >> "$LOG"

# All heavy work runs in the background so Claude Code is not blocked
(
  set +e

  # ── Android emulator ─────────────────────────────────────────────────────
  echo "[android] checking emulator..." >> "$LOG"
  if ! "$ADB" devices 2>/dev/null | grep -q emulator; then
    avd=$("$ANDROID_EMU" -list-avds 2>/dev/null | head -1)
    if [ -n "$avd" ]; then
      echo "[android] booting $avd" >> "$LOG"
      nohup "$ANDROID_EMU" -avd "$avd" >> /tmp/android-emulator.log 2>&1 &
      # Poll until the emulator shows up in adb (max 60 s)
      for i in $(seq 1 20); do
        sleep 3
        "$ADB" devices 2>/dev/null | grep -q emulator && { echo "[android] online" >> "$LOG"; break; }
      done
    else
      echo "[android] no AVD found" >> "$LOG"
    fi
  else
    echo "[android] emulator already running" >> "$LOG"
  fi

  # ── iOS simulator ─────────────────────────────────────────────────────────
  echo "[ios] checking simulator..." >> "$LOG"
  if ! xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
    # Pick the latest available iPhone simulator
    sim_udid=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E 'iPhone' | grep -v 'unavailable' \
      | tail -1 | grep -oE '[A-F0-9-]{36}')
    if [ -n "$sim_udid" ]; then
      echo "[ios] booting $sim_udid" >> "$LOG"
      xcrun simctl boot "$sim_udid" 2>/dev/null || true
      open -a Simulator 2>/dev/null || true
      sleep 8
    else
      echo "[ios] no simulator found" >> "$LOG"
    fi
  else
    echo "[ios] simulator already booted" >> "$LOG"
  fi

  # ── flutter test ──────────────────────────────────────────────────────────
  echo "[test] running flutter test..." >> "$LOG"
  cd "$PROJECT"
  "$FLUTTER" test > /tmp/flutter-test.log 2>&1
  test_exit=$?
  echo "[test] exit code: $test_exit" >> "$LOG"
  # Surface test result as a system message back to Claude Code
  if [ "$test_exit" -ne 0 ]; then
    echo '{"systemMessage":"⚠️  flutter test failed after push — check /tmp/flutter-test.log"}'
  fi

  # ── flutter run on both platforms ─────────────────────────────────────────
  echo "[run] starting flutter run -d ios" >> "$LOG"
  nohup "$FLUTTER" run -d ios > /tmp/flutter-run-ios.log 2>&1 &

  echo "[run] starting flutter run -d android" >> "$LOG"
  nohup "$FLUTTER" run -d android > /tmp/flutter-run-android.log 2>&1 &

  echo "[done] $(date)" >> "$LOG"
) >> "$LOG" 2>&1 &

exit 0
