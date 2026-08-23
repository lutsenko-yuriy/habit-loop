```bash
gh pr create \
  --title "<type>: <summary>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet points>

## Issue
Closes HAB-XX

## Test plan
- [ ] <what was tested>
- [ ] flutter test passes
- [ ] flutter analyze passes
- [ ] Smoke tested

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

**If the PR touches `scripts/` (Python tooling) and no `lib/` files** (HAB-247 debrief, 2026-08-24): add a `## What this means` section right after `## Summary`, written in plain, non-technical language — the reviewer relies on this to follow the change since they don't read Python fluently. Explain what actually changes in behaviour, not how the code does it (no function/regex/class names).
