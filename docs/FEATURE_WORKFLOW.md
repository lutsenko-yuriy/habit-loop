# Feature Workflow

Use this workflow for new features, enhancements, and planned changes.
For bugs, CI failures, regressions, or infrastructure breakage, use `docs/TROUBLESHOOT_WORKFLOW.md` instead.

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

@skills/shared/decision-principles.md

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

## Steps

1. **Planning & setup gates** — work through in order; skip any that don't apply:
   1. **Sharpen the spec.** If the ticket lacks a clear UX spec (no explicit description of UI behaviour, interaction, or screen layout), or predates the `/brief` skill: run `/brief` first, before anything else below.
   2. **Analytics planning.** For features with user-visible screens or interactions: invoke `analyze` and wait for approval.
      ```
      Invoke the analyze skill for HAB-XX: <issue title>
      ```
      Identifies trackable moments, proposes events and screen views, flags PII concerns, updates `docs/ANALYTICS_EVENTS.md`. Pure infrastructure or CI changes with no user-facing screens skip this gate.
   3. **Implementation plan.** For large changes (spanning multiple files, introducing new domain entities, new dependencies, or architectural shifts): invoke `plan` and wait for approval, before writing any code.
      ```
      Invoke the plan skill for HAB-XX: <issue title>
      ```
      Produces a structured plan (dependencies, models, UI changes, test strategy, ordered phases, work units).
   4. **Feature toggle.** For features introducing new user-facing behaviour: consider a Firebase Remote Config kill-switch flag (default `true`) so the feature can be disabled remotely without a release if a critical regression surfaces after shipping. If added, document it in `docs/FEATURE_TOGGLES.md` before writing any code.
   5. **Create the feature branch** from the latest `main`, before writing any code. Always include the Linear ticket number after `feature/`:
      ```
      git fetch origin
      git checkout -b feature/HAB-XX-<short-description> origin/main
      ```
      If the branch already exists, rebase it onto `origin/main` first (`git rebase origin/main`) so the PR diff contains only the new work. **Before merging**, rebase onto `origin/main` again (`git fetch origin && git rebase origin/main`) so the branch is current and the merge lands cleanly.
   6. **Draft scenarios.** For every ticket with user-facing flows: invoke `draft-scenarios` and wait for approval.
      ```
      Invoke the draft-scenarios skill for HAB-XX: <issue title>
      ```
      Reads the ticket (and any `plan` comment), drafts scenario stubs with `// TODO:` comments in `integration_test/` using `AppHarness`. `implement` fills in driver code per WU and makes them green. Pure infrastructure or CI-only changes with no user-facing flows may skip this gate.

   **A note on CI/infrastructure tickets:** for tickets that bring up a new CI/infrastructure target (a new platform's test job, a new emulator, first real-device timing), expect the scope to balloon once real failures start surfacing — this class of issue can only be caught by running against the real target, not in planning. If it does balloon, split the ticket: merge the CI wiring/job setup on its own once it's mechanically correct, and track scenario/flakiness stabilization as a separate follow-up ticket rather than blocking the original PR on every fix.

   **Multi-WU tickets:** if the approved plan (1.3) contains more than one production work unit, see the [Multi-WU tickets](#multi-wu-tickets) appendix before continuing — it changes how steps 2–12 below are repeated.

2. For features with user-visible screens or interactions: draft widget tests before writing production code:
   - Create new widget tests covering each new screen and key user flow (swiping, tapping, navigation, locale changes, auto-advance, etc.).
   - Update any existing widget tests that the new screens or UI changes will affect.
   - Present all new and updated widget test files to the user and wait for approval.
   - Do not continue to step 3 until the user approves the widget tests.
3. **TDD micro-cycle** — repeat for each logical unit of work within the WU:
   1. **Red** — Write a small set of failing unit tests for one logical unit of work.
   2. **Green** — Implement the minimum code to make them pass.
      **Opportunistic changes:** If an idea arises to modify existing or in-flight functionality, write the integration test for that change first. Never modify observable behaviour without a covering integration test.
   3. **Refactor and commit** — Clean up without breaking tests, then commit this micro-cycle as one atomic commit before moving to the next logical unit:
      ```
      git commit -m "feat: <what this logical unit does>"
      ```
      During refactor, look for simple algorithmic improvements that don't hurt readability — e.g. a single-pass loop instead of two iterations over the same collection, or avoiding redundant allocations. Apply them inline; do not defer to a follow-up ticket.

   Each PR accumulates one commit per cycle — reviewable commit-by-commit on GitHub.
4. Run `flutter test` and `flutter analyze` — fix **all** test failures and analyzer warnings/errors before proceeding. A clean analyzer output (`No issues found`) is required before committing; do not leave warnings unresolved on the assumption they are pre-existing.
5. After all TDD micro-cycles are complete, apply formatting in a dedicated commit before opening the PR: run `dart format -l 120 lib/ test/ integration_test/` and, if any files changed, stage and commit them separately with a `style:` prefix (e.g. `style: apply dart format`). This keeps style changes reviewable in isolation from logic changes.
6. Update documentation if affected by the changes:
   - `CLAUDE.md` — architecture, conventions, or workflow changed
   - `@docs/PRODUCT_SPEC.md` — functionality added, removed, or changed
   - `@docs/ARCHITECTURE.md` — code structure or dependencies changed
   - `@docs/VERSIONING.md` — CI/CD or versioning process impacted
7. **Keep `pubspec.yaml` version in sync with `docs/CHANGELOG.md`.** Before committing, check that the version name (`X.Y.Z`) in `pubspec.yaml` matches the latest `[X.Y.Z]` entry in `CHANGELOG.md`. If a new changelog entry was added in this PR, update `pubspec.yaml` accordingly. Do not touch the build number — CI manages it.

   **Release note tagging (enforced by CI — `scripts/changelog/lint.py` runs on every PR):** every new `## [X.Y.Z]` CHANGELOG entry must carry at least one classification tag. See the tag taxonomy table in `docs/VERSIONING.md` for the full list and their build/release-note behaviour.

   `[user]` bullets are read directly by end users as "What's New" text — write in plain language with no ticket numbers, WU prefixes, class names, RC key names, or internal terms. See `skills/manage/ship/resources/changelog-tags.md` for examples and anti-patterns.

   **Never commit a CHANGELOG entry with no classification tag — CI will fail.**
8. Commit all changes with a descriptive message.
9. Push to the remote and open a PR — all in parallel:
   - Push the branch to the remote.
   - Open a PR.
   - Move the Linear ticket to **In Review**.
   - Inform the user of the PR URL.
   - The `implement` skill invokes `review-architecture` and `audit-code` automatically after the PR is open.
10. **Review loop** — repeat until the user explicitly approves the PR:
    1. Wait for both review skills (`review-architecture`, `audit-code`), the Codecov patch-coverage report, and the user to finish leaving comments.
    2. For each comment: either fix it in a new commit and push, or post a one-sentence explanation of why the fix will not be implemented.
    3. Check the Codecov patch-coverage report (posted automatically as a PR comment by CI). If patch coverage is below the project threshold, add tests for the uncovered lines where it is reasonable to do so — skip lines that require disproportionate test infrastructure (e.g. `ConsumerStatefulWidget` screens with no widget-test harness). Explain skipped lines in a PR comment.
    4. If the cumulative changes since the last review pass are non-trivial (new files, logic changes, interface changes), re-invoke both review skills and return to step 10.1.
    5. Minor fixes (typos, cosmetic, comment wording) do not require a re-review pass.
    6. The loop ends only when the user explicitly approves ("LGTM", "looks good", "approved", etc.).
11. Remind the user to clear the context after each commit to keep the conversation lean.
12. When the user approves the PR, invoke the `ship` skill:
    ```
    Invoke the ship skill for PR #<number>
    ```
    The skill moves the Linear ticket to **In QA**, adds a CHANGELOG entry, regenerates BACKLOG.md, bumps `pubspec.yaml` version, commits onto the feature branch, pushes, and merges. No separate approval is needed for the version bump.
    Integration scenarios run automatically on CI after merge (see HAB-151). Use `/run-scenarios` manually if you want to verify locally before merging.
13. Clear the context after the PR is merged. The ticket stays **In QA** until the user confirms QA has passed — at that point the user moves it to **Done** in Linear manually.
14. A new ticket may be picked up while the previous one is In QA.

---

## Multi-WU tickets

When the approved plan (step 1.3) contains more than one production work unit (WU1+), follow these rules in addition to the standard workflow.

**WU0 — scenarios only**

After scenarios are approved and written (step 1.6), commit them to `feature/HAB-XX-WU0-scenarios`, push, and open a PR titled `test(WU0): integration scenarios (HAB-XX)`. Use `[test]` as the CHANGELOG classification tag. Merge WU0 directly — no `ship`, no version bump. Each subsequent WU's plan entry lists which scenarios it makes green.

**One WU = one branch = one PR**

Each WU gets its own branch (`feature/HAB-XX-WUN-<short>`, where N is the WU number from the plan's WU table) created fresh from `origin/main`. Never reuse a branch from a previous WU. Branch names are pre-named in the plan comment's WU table so the full mapping is visible from day one.

**CHANGELOG tags for intermediate WUs**

Use `[wip]` as the classification tag for all intermediate WU CHANGELOG entries — every WU except the final one that makes the feature user-visible. `[wip]` suppresses builds and distribution so testers do not receive partial builds mid-ticket. The final WU uses `[user]` (and/or `[app]`) — this is when CI builds and distributes, and "What's New" aggregates all `[user]` content back to the last published tag.

**WU cycle (WU1 onwards)**

For each WU in sequence:
1. Create a fresh branch from the latest `origin/main` using the branch name from the plan table.
2. Follow steps 2–12 (widget tests, TDD cycles, validate, format, PR, review loop, ship). The full review loop (step 10) — `review-architecture`, `audit-code`, Codecov, and user sign-off — is mandatory for every WU PR without exception.
3. After `ship` merges, fetch `origin/main` and start the next WU from the freshly updated tip.
