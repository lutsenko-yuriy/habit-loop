# Workflow

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

**Ticket states and parallelism rules:**
- **In Progress** → active development; only one ticket may be In Progress at a time.
- **In Review** → PR is open; code review (architectural + audit) is happening.
- **In QA** → PR is merged; CI/CD and human testers are validating on real devices. A new ticket **may** be picked up while another is In QA.
- **Done** → QA has signed off; the user moves the ticket to Done manually.

Before picking up any new ticket, check Linear to confirm no other ticket is In Progress (In QA is fine).

**When to use In QA vs Done directly after merge:**

Move to **In QA** if the PR touches any of:
- `lib/slices/*/ui/` — any widget or screen change
- `lib/infrastructure/persistence/` — schema migrations or mapper changes
- `lib/infrastructure/sync/` — Firestore or circuit-breaker behaviour
- `lib/infrastructure/notifications/` — notification scheduling
- `main.dart` — app wiring or startup sequence
- `integration_test/` — **always In QA if integration tests were added or changed**

Move straight to **Done** (skip In QA) if the PR touches only:
- Pure domain/application logic with no runtime platform dependency (`lib/domain/`, `lib/slices/*/application/`)
- Documentation or workflow files (`docs/`, `AGENTS.md`, `skills/`)
- CI configuration (`.github/`)
- l10n strings with no new screens
- Pure refactors or test-only changes where `flutter test` fully owns correctness

When in doubt, use **In QA**.

**For features with user-visible screens or interactions**: invoke the `analyze` skill first for analytics planning before planning implementation:

```
Invoke the analyze skill for HAB-XX: <issue title>
```

The skill will identify trackable moments, propose events and screen views, flag PII concerns, update `docs/ANALYTICS_EVENTS.md`, and wait for approval. Pure infrastructure or CI changes with no user-facing screens skip this step.

**For large changes** (spanning multiple files, introducing new domain entities, new dependencies, or architectural shifts): invoke the `plan` skill to produce the implementation plan **before writing any code**:

**Algorithm + pagination compatibility:** when the plan introduces a service that transforms the full dataset (grouping, ranking, aggregation), verify at plan time that a paged API is compatible. If the algorithm requires a full pass, design the service as `loadAll()` and push windowing to the ViewModel layer.

```
Invoke the plan skill for HAB-XX: <issue title>
```

The skill will produce a structured plan (dependencies, models, UI changes, test strategy, ordered phases, work units) and wait for the user to approve or adjust it.

**If the ticket lacks a clear UX spec** (no explicit description of UI behaviour, interaction, or screen layout), or predates the `/brief` skill: run `/brief` first to sharpen the spec before any planning begins.

**For features introducing new user-facing behaviour**: consider adding a Firebase Remote Config kill-switch flag (default `true`) so the feature can be disabled remotely without a release if a critical regression is discovered after shipping. If warranted, document the flag in `docs/FEATURE_TOGGLES.md` before writing any code.

**For every ticket with user-facing flows**: invoke the `draft-scenarios` skill to write scenarios (integration tests) from the spec before any production code:

```
Invoke the draft-scenarios skill for HAB-XX: <issue title>
```

The skill reads the ticket and any plan comment, drafts scenario stubs with `// TODO:` comments covering the happy path and critical failure cases using `AppHarness`, waits for approval, and writes the approved stubs. `implement` fills in driver code per WU and makes them green. Pure infrastructure or CI-only changes with no user-facing flows may skip this step.

1. For features with user-facing screens/interactions, invoke `analyze` first and wait for approval.
2. For large changes, invoke `plan` and wait for plan approval.
3. Create a new feature branch from the latest `main` and switch to it before writing any code. Always include the Linear ticket number after `feature/`:
   ```
   git fetch origin
   git checkout -b feature/HAB-XX-<short-description> origin/main
   ```
   If the branch already exists, rebase it onto `origin/main` before writing any code (`git rebase origin/main`). This ensures the PR diff contains only the new work.
   **Before merging**, always rebase the branch onto the latest `origin/main` again (`git fetch origin && git rebase origin/main`) so the branch is up to date and the merge lands cleanly on the current tip.
4. Invoke the `draft-scenarios` skill to draft scenarios (integration tests) from the ticket spec:

   ```
   Invoke the draft-scenarios skill for HAB-XX: <issue title>
   ```

   The skill reads the ticket (and any `plan` comment), drafts scenario stubs with `// TODO:` comments in `integration_test/` using `AppHarness`, waits for approval, and writes the approved stubs. `implement` fills in driver code per WU and makes them green. Pure infrastructure or CI-only changes with no user-facing flows may skip this step.

### 4.1 Multi-WU tickets

When the approved plan contains more than one production work unit (WU1+), follow these rules in addition to the standard workflow.

**WU0 — scenarios only**

After scenarios are approved and written, commit them to `feature/HAB-XX-WU0-scenarios`, push, and open a PR titled `test(WU0): integration scenarios (HAB-XX)`. Use `[test]` as the CHANGELOG classification tag. Merge WU0 directly — no `ship`, no version bump. Each subsequent WU's plan entry lists which scenarios it makes green.

**One WU = one branch = one PR**

Each WU gets its own branch (`feature/HAB-XX-WUN-<short>`, where N is the WU number from the plan's WU table) created fresh from `origin/main`. Never reuse a branch from a previous WU. Branch names are pre-named in the plan comment's WU table so the full mapping is visible from day one.

**CHANGELOG tags for intermediate WUs**

Use `[wip]` as the classification tag for all intermediate WU CHANGELOG entries — every WU except the final one that makes the feature user-visible. `[wip]` suppresses builds and distribution so testers do not receive partial builds mid-ticket. The final WU uses `[user]` (and/or `[app]`) — this is when CI builds and distributes, and "What's New" aggregates all `[user]` content back to the last published tag.

**WU cycle (WU1 onwards)**

For each WU in sequence:
1. Create a fresh branch from the latest `origin/main` using the branch name from the plan table.
2. Follow steps 5–17 (TDD cycles, validate, format, PR, review loop, ship). The full review loop (step 15) — `review-architecture`, `audit-code`, Codecov, and user sign-off — is mandatory for every WU PR without exception.
3. After `ship` merges, fetch `origin/main` and start the next WU from the freshly updated tip.

---

5. For features with user-visible screens or interactions: draft widget tests before writing production code:
   - Create new widget tests covering each new screen and key user flow (swiping, tapping, navigation, locale changes, auto-advance, etc.).
   - Update any existing widget tests that the new screens or UI changes will affect.
   - Present all new and updated widget test files to the user and wait for approval.
   - Do not continue to step 6 until the user approves the widget tests.
6. **Red** — Write a small set of failing unit tests for one logical unit of work.
7. **Green** — Implement the minimum code to make them pass.
   **Opportunistic changes:** If an idea arises to modify existing or in-flight functionality, write the integration test for that change first. Never modify observable behaviour without a covering integration test.
8. **Refactor and commit** — Clean up without breaking tests, then commit this TDD micro-cycle as one atomic commit before moving to the next logical unit:
   ```
   git commit -m "feat: <what this logical unit does>"
   ```
   Repeat steps 6–8 for each logical unit within the WU. Each PR accumulates one commit per cycle — reviewable commit-by-commit on GitHub.
9. Run `flutter test` and `flutter analyze` — fix **all** test failures and analyzer warnings/errors before proceeding. A clean analyzer output (`No issues found`) is required before committing; do not leave warnings unresolved on the assumption they are pre-existing.
10. After all TDD micro-cycles are complete, apply formatting in a dedicated commit before opening the PR: run `dart format -l 120 lib/ test/ integration_test/` and, if any files changed, stage and commit them separately with a `style:` prefix (e.g. `style: apply dart format`). This keeps style changes reviewable in isolation from logic changes.
11. Update documentation if affected by the changes:
    - `CLAUDE.md` — architecture, conventions, or workflow changed
    - `@docs/PRODUCT_SPEC.md` — functionality added, removed, or changed
    - `@docs/ARCHITECTURE.md` — code structure or dependencies changed
    - `@docs/VERSIONING.md` — CI/CD or versioning process impacted
12. **Keep `pubspec.yaml` version in sync with `docs/CHANGELOG.md`.** Before committing, check that the version name (`X.Y.Z`) in `pubspec.yaml` matches the latest `[X.Y.Z]` entry in `CHANGELOG.md`. If a new changelog entry was added in this PR, update `pubspec.yaml` accordingly. Do not touch the build number — CI manages it.
    **Release note tagging (enforced by CI — `scripts/changelog/lint.py` runs on every PR):**
    Every new `## [X.Y.Z]` CHANGELOG entry MUST contain at least one classification tag. Pick the tag that best describes the change:

    | Tag | Meaning | Firebase distribution? | Release notes? |
    |---|---|---|---|
    | `[user]` | User-visible app change | Yes | Yes |
    | `[app]` | App code change, not user-visible | Yes | No |
    | `[test]` | Test-only changes (unit tests, scenarios, widget tests) — no production code | No | No |
    | `[meta]` | Skills / agent / workflow change | No | No |
    | `[ci]` | CI/CD process change | No | No |
    | `[user-none]` | Entire entry is internal-only (legacy sentinel) | No | No |

    `[non-user]` may be used as a supplementary tag on individual bullets within an entry that already has a classification tag. It does **not** satisfy the classification requirement on its own.

    Only `[user]` lines appear in Firebase App Distribution release notes. All other tags are stripped.
    The tag list may be extended over time; any new tag must declare its distribution and release-note behaviour.

    **Never commit a CHANGELOG entry with no classification tag — CI will fail.**
13. Commit all changes with a descriptive message.
14. Push to the remote and open a PR — all in parallel:
    - Push the branch to the remote.
    - Open a PR.
    - Move the Linear ticket to **In Review**.
    - Inform the user of the PR URL.
    - The `implement` skill invokes `review-architecture` and `audit-code` automatically after the PR is open.
15. **Review loop** — repeat until the user explicitly approves the PR:
    1. Wait for both review skills (`review-architecture`, `audit-code`), the Codecov patch-coverage report, and the user to finish leaving comments.
    2. For each comment: either fix it in a new commit and push, or post a one-sentence explanation of why the fix will not be implemented.
    3. Check the Codecov patch-coverage report (posted automatically as a PR comment by CI). If patch coverage is below the project threshold, add tests for the uncovered lines where it is reasonable to do so — skip lines that require disproportionate test infrastructure (e.g. `ConsumerStatefulWidget` screens with no widget-test harness). Explain skipped lines in a PR comment.
    4. If the cumulative changes since the last review pass are non-trivial (new files, logic changes, interface changes), re-invoke both review skills and return to step 15.1.
    5. Minor fixes (typos, cosmetic, comment wording) do not require a re-review pass.
    6. The loop ends only when the user explicitly approves ("LGTM", "looks good", "approved", etc.).
16. Remind the user to clear the context after each commit to keep the conversation lean.
17. When the user approves the PR, run the full integration test suite via the `run-scenarios` skill before invoking `ship`:
    ```
    Invoke the run-scenarios skill
    ```
    Or: `/run-scenarios`
    All scenarios must be green. Do not invoke `ship` if any scenario is failing. Once they pass, invoke the `ship` skill:
    ```
    Invoke the ship skill for PR #<number>
    ```
    The skill moves the Linear ticket to **In QA**, adds a CHANGELOG entry, regenerates BACKLOG.md, bumps `pubspec.yaml` version, commits onto the feature branch, pushes, and merges. No separate approval is needed for the version bump.
18. Clear the context after the PR is merged. The ticket stays **In QA** until the user confirms QA has passed — at that point the user moves it to **Done** in Linear manually.
19. A new ticket may be picked up while the previous one is In QA.
