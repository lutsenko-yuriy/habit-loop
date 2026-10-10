#!/bin/bash
# Test harness for session_start.sh — runs the hook against scratch git repos
# with and without the onboarding marker (HAB-278) and asserts on the injected
# additionalContext.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/session_start.sh"
pass=0
fail=0

ONBOARDED=$(mktemp -d)
FRESH=$(mktemp -d)
NOT_A_REPO=$(mktemp -d)
trap 'rm -rf "$ONBOARDED" "$ONBOARDED-wt" "$FRESH" "$NOT_A_REPO"' EXIT

git -C "$ONBOARDED" init -q
git -C "$FRESH" init -q
mkdir -p "$ONBOARDED/.git/yab" && touch "$ONBOARDED/.git/yab/onboarded"
git -C "$ONBOARDED" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
WORKTREE="$ONBOARDED-wt"
git -C "$ONBOARDED" worktree add -q "$WORKTREE"

context_for() {
  echo '{}' | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" | jq -r '.hookSpecificOutput.additionalContext'
}

check() {
  local desc="$1" dir="$2" want="$3" unwanted="$4"
  local out
  out=$(context_for "$dir")
  if echo "$out" | grep -qF "$want" && ! echo "$out" | grep -qF "$unwanted"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    echo "$out" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
}

check "onboarded clone runs the checklist" "$ONBOARDED" "Invoke the summarize skill" "/onboard"
check "linked worktree of an onboarded clone runs the checklist" "$WORKTREE" "Invoke the summarize skill" "/onboard"
check "clone without marker defers to /onboard" "$FRESH" "/onboard" "Invoke the summarize skill"
check "no git repo defers to /onboard" "$NOT_A_REPO" "/onboard" "Invoke the summarize skill"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
