---
bookmarks: [stale-ticket]
---

# HAB-238: Bug: block-main-writes.sh false-positives on commit messages that mention push/main in prose

## Notes

### 2026-08-17

**Quote-stripping fix doesn't cover heredoc bodies**

Hit while opening HAB-241's PR via `gh pr create --body-file` sourced from a `cat
<<'EOF' > file` heredoc: the heredoc body mentioned "push"/"main" in prose
("...no direct commits/pushes to main... git push --no-verify.") and still tripped
pattern-1, even after HAB-238's fix. The fix's `sed -E 's/"[^"]*"//g;
s/'"'"'[^'"'"']*'"'"'//g'` only strips `"..."`/`'...'` quoted spans — a heredoc's
body is not quoted syntax at all, so bare trigger words inside it pass through
untouched. Worked around by writing the file via the Write tool instead of a Bash
heredoc. Worth a follow-up fix (extend quote-stripping to heredoc bodies, or scope
the push+main match more narrowly) if this recurs.

## Debrief summary
