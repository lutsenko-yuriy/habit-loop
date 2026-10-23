---
bookmarks: [review-findings, changelog-versioning, cross-project-sync]
---

# YAB-44: Versioning and release notes move out of /ship into /prepare-release

YAB issue: https://github.com/lutsenko-yuriy/yuriys-agentic-boyz/issues/44. WU1 is PR #48 (`changelog.py` and `/ship` writing marked lines); WU2 is PR #49 (`[release]` config, `cut`/`notes`/`latest`, `/prepare-release`). This note lives in Habit Loop only until YAB #46 moves it into the dev project.

## Notes

## Debrief summary

### 2026-10-23

**What went well**
- The brief and the plan held through both WUs: every `/ship` line carries a MAJOR/MINOR/PATCH mark and its flags, and `/prepare-release` selects lines, drafts notes, proposes the version, then commits, tags, runs the job and switches flags on.
- Review caught 10 real issues before merge. In WU1 the audit found that the new lint would turn adopters' CI red (Habit Loop: 164 findings), which led to the opt-in `<!-- changelog-format: yab-1 -->` marker. The user was glad these were caught before merging rather than earlier.
- The user tested `/prepare-release` in a throwaway project: the release notes read as human-written, and the summary screen was better than expected.

**What was hard or surprising**
- Edge cases in `cut`: a trailing space on the `[Unreleased]` heading, comments and subheadings being dropped, CRLF line endings, and a mark placed after a trailing HTML comment.
- Merge methods differ per repo: `--merge` fails where only squash is allowed, and `glab` follows the GitLab project's own setting.
- Both review agents hit the session usage limit and had to be resumed.

**What to change**
- The implementer committed a fix with its new test failing, because `| tail` hid the failing exit status; the next commit fixed it. `skills/build/implement/SKILL.md` (YAB and Habit Loop) now says to confirm from the exit status that the tests passed.
