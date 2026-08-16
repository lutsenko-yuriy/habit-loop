# Troubleshooting Workflow

Use this workflow for reactive work: CI failures, regressions, infrastructure breakage, build system issues.
For new features, enhancements, and planned changes, use `docs/workflows/FEATURE.md` instead.

@skills/shared/decision-guidelines.md

## 1. Identify and reproduce

- Confirm the problem is real by checking CI logs or reproducing locally.
- Note the first failing commit or PR if identifiable.
- State the problem in one sentence before going further.

## 2. Investigate

- Check recent changes: `git log --oneline -20`, recent PRs, recent dependency bumps.
- For third-party tool failures: read the changelog for breaking changes around the time the failure started.
- **Before writing off a failing integration test as "known flaky"**, re-run it in isolation at least once to confirm it's actually intermittent, not deterministic. A symptom that looks like known flakiness (e.g. a `waitFor` timeout) can be a real, consistent bug wearing the same clothes (HAB-198: a stale assertion failed the same way every time for three WUs before anyone re-ran it and noticed it never once passed).
- Form a hypothesis before attempting any fix. **If a hypothesis is disproven by a live CI run, don't form a second one from code reading alone** — add targeted diagnostic instrumentation (print the actual widget rect, viewport size, scroll offset, etc.) and validate against real data before the next attempt. Two hypotheses were disproven this way in HAB-196; HAB-199 repeated the same guessing before applying the lesson (see docs/knowledge/notes/HAB-196.md).

- **Same rule for a visual/animation bug** (color, timing, flicker) reported by the user: if a fix attempt doesn't resolve it, ask for a short screen recording and extract frames with `ffmpeg -i video.mov -vf fps=30 frame_%03d.png` to see the actual rendered state at each moment, instead of forming another hypothesis from widget code alone. HAB-213 WU3 went through several fix/revert cycles on a button color flash before trying this.

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
- If the fix loop looks like it will need multiple real CI dispatches to validate (e.g. CI-only environment flakiness), say so explicitly — at ticket start if apparent from the outset, or the moment it becomes apparent mid-ticket — so the user can choose to step away (e.g. overnight) instead of staying attached through every dispatch.

## 5. Ship

Once a fix works, follow `docs/workflows/FEATURE.md` steps 7–13 (CHANGELOG, version bump, PR, review, debrief, merge via `/ship`).
