#!/bin/bash
# PreToolUse hook — fires before every Bash tool call.
# Enforces the "feature branch + PR only" rule by blocking the two most common
# direct-to-main slips early, with a model-facing message:
#   1. an explicit push whose destination is main
#   2. a standalone `git commit` while checked out on main
#
# The airtight backstop is the local .git/hooks/pre-push hook, which inspects
# the actual ref being pushed (refs/heads/main) and catches anything this
# heuristic misses (e.g. a bare `git push` from main) with zero false positives.
#
# Exit 2 = block the tool call and return the stderr message to Claude.
# Exit 0 = allow.

PROJECT=/Users/yurich/claude_projects/habit_loop

# Must consume stdin (hook input JSON).
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

# Only inspect git commands; everything else passes through.
printf '%s' "$cmd" | grep -qE '\bgit\b' || exit 0

deny() { echo "$1" >&2; exit 2; }

# Detect the repo being operated on from the command (cd .../path && git ...).
# Fall back to the habit_loop project dir if no explicit path is found.
_repo_dir=$(printf '%s' "$cmd" | grep -oE 'cd [^&;|]+' | head -1 | sed 's/^cd //' | xargs 2>/dev/null)
[ -d "$_repo_dir/.git" ] || _repo_dir="$PROJECT"
branch=$(git -C "$_repo_dir" branch --show-current 2>/dev/null)

# 1) Explicit push to main — block regardless of the current branch.
#    Matches `... main` / `:main` / `HEAD:main` as a complete ref token, but not
#    branch names that merely contain "main" (e.g. feature/main-menu).
if printf '%s' "$cmd" | grep -qE '\bpush\b' \
   && printf '%s' "$cmd" | grep -qE '([[:space:]:]|^)main([[:space:]]|$)'; then
  deny "BLOCKED: this push targets main. Push a feature branch and open a PR instead (no direct commits/pushes to main). Override only if truly intended: git push --no-verify."
fi

# 2) Standalone commit while on main. Skipped when the command also switches
#    branch (e.g. `git checkout -b feature/x && git commit ...`), which is fine.
if [ "$branch" = "main" ] \
   && printf '%s' "$cmd" | grep -qE '\bcommit\b' \
   && ! printf '%s' "$cmd" | grep -qE '\b(checkout|switch)\b'; then
  deny "BLOCKED: 'git commit' on main. Create a feature branch first: git checkout -b feature/HAB-XX-<desc>."
fi

exit 0
