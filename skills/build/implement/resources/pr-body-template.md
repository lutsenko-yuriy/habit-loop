```bash
gh pr create \
  --title "<type>: <summary>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet points>

## Linear
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
