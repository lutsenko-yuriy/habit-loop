#!/bin/bash
# Test harness for block-main-writes.sh — pipes representative hook JSON
# payloads through the script against two scratch git repos (one on `main`,
# one on a feature branch) and asserts on exit code + stderr message.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/block-main-writes.sh"
pass=0
fail=0

MAIN_REPO=$(mktemp -d)
FEATURE_REPO=$(mktemp -d)

setup_repo() {
  local dir="$1" branch="$2"
  git -C "$dir" init -q -b "$branch"
  git -C "$dir" -c user.email=test@test.com -c user.name=test commit -q --allow-empty -m "init"
  [ "$branch" = "main" ] || git -C "$dir" checkout -q -b "$branch" 2>/dev/null || true
}

setup_repo "$MAIN_REPO" main
setup_repo "$FEATURE_REPO" feature/test-branch

run_hook() {
  local cmd="$1"
  printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | bash "$HOOK"
}

check_blocked() {
  local desc="$1" cmd="$2" expected_msg="$3"
  local out rc
  out=$(run_hook "$cmd" 2>&1 1>/dev/null)
  rc=$?
  if [ "$rc" -eq 2 ] && echo "$out" | grep -qF "$expected_msg"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (rc=$rc)"
    echo "  --- output ---"
    echo "$out" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
}

check_allowed() {
  local desc="$1" cmd="$2"
  local out rc
  out=$(run_hook "$cmd" 2>&1 1>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (rc=$rc, expected 0)"
    echo "  --- output ---"
    echo "$out" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
}

# 1. THE BUG (HAB-238): commit message prose mentions push+main, no push
#    actually happening, on a feature branch -> must be allowed. "main" must
#    be preceded by whitespace/colon and followed by whitespace (a bare word
#    match, not e.g. "origin/main" where the "/" prefix already dodges the
#    pattern) to actually exercise the reported word-boundary match.
check_allowed "commit message prose mentioning push+main -> allowed" \
  "cd $FEATURE_REPO && git commit -m \"fix: switch git push to --force-with-lease when rebasing onto main branch\""

# 2. Same false-positive shape with single-quoted message.
check_allowed "single-quoted commit message mentioning push+main -> allowed" \
  "cd $FEATURE_REPO && git commit -m 'push to main later'"

# 3. Real push targeting main must still be blocked.
check_blocked "git push origin main -> blocked" \
  "cd $FEATURE_REPO && git push origin main" \
  "BLOCKED: this push targets main"

# 4. Real push via HEAD:main must still be blocked.
check_blocked "git push origin HEAD:main -> blocked" \
  "cd $FEATURE_REPO && git push origin HEAD:main" \
  "BLOCKED: this push targets main"

# 5. Push to a branch that merely contains "main" as a substring must not block.
check_allowed "git push origin feature/main-menu -> allowed" \
  "cd $FEATURE_REPO && git push origin feature/main-menu"

# 6. Standalone commit while checked out on main must still be blocked
#    (pattern-2 check, untouched by this fix).
check_blocked "standalone commit on main -> blocked" \
  "cd $MAIN_REPO && git commit -m 'docs: update'" \
  "BLOCKED: 'git commit' on main"

# 7. Commit combined with a branch switch must still be allowed.
check_allowed "checkout -b + commit -> allowed" \
  "cd $MAIN_REPO && git checkout -b feature/x && git commit -m 'test'"

# 8. Non-git command mentioning push/main passes through untouched.
check_allowed "non-git command mentioning push/main -> allowed" \
  "echo 'we should push to main sometime'"

rm -rf "$MAIN_REPO" "$FEATURE_REPO"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
