# Troubleshooting Workflow

Use this workflow for reactive work: CI failures, regressions, infrastructure breakage, build system issues.
For new features, enhancements, and planned changes, use `docs/FEATURE_WORKFLOW.md` instead.

@skills/shared/decision-principles.md

## 1. Identify and reproduce

- Confirm the problem is real by checking CI logs or reproducing locally.
- Note the first failing commit or PR if identifiable.
- State the problem in one sentence before going further.

## 2. Investigate

- Check recent changes: `git log --oneline -20`, recent PRs, recent dependency bumps.
- For third-party tool failures: read the changelog for breaking changes around the time the failure started.
- Form a hypothesis before attempting any fix.

## 3. Open a tracking ticket

**Before attempting more than one fix**, open a Linear ticket with:
- Problem description and first observed failure
- What has already been tried and why it failed
- Candidate solutions with a trade-off analysis

**When candidates include third-party GitHub Actions or OSS dependencies**, include a health check for each in the trade-off table:

| Signal | How to fetch |
|---|---|
| License | `gh api repos/{owner}/{repo} --jq '.license.spdx_id'` |
| Open issues (count + nature) | `gh api "repos/{owner}/{repo}/issues?state=open&per_page=25"` |
| Last commit date | `gh api repos/{owner}/{repo} --jq '.pushed_at'` |
| Stars / forks | same API call |

Present this alongside the trade-off table, not only when asked.

## 4. Attempt fixes systematically

- One branch per attempt: `feature/HAB-XX-<short-description>`
- Record each failed attempt in the ticket description before moving on.
- Use `workflow_dispatch` or equivalent to test CI fixes without merging.

## 5. Ship

Once a fix works, follow `docs/FEATURE_WORKFLOW.md` steps 7–12 (CHANGELOG, version bump, PR, review, merge via `/ship`).
