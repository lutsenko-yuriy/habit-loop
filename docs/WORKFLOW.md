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

```
Invoke the plan skill for HAB-XX: <issue title>
```

The skill will produce a structured plan (dependencies, models, UI changes, test strategy, ordered phases, work units) and wait for the user to approve or adjust it.

**For every ticket with user-facing flows**: invoke the `validate` skill to write integration tests from the spec before any production code:

```
Invoke the validate skill for HAB-XX: <issue title>
```

The skill reads the ticket and any plan comment, drafts integration tests covering the happy path and critical failure scenarios using `AppHarness`, waits for approval, and writes the approved test files. Tests are intentionally red — `implement` uses them as its red-green target. Pure infrastructure or CI-only changes with no user-facing flows may skip this step.

1. For features with user-facing screens/interactions, invoke `analyze` first and wait for approval.
2. For large changes, invoke `plan` and wait for plan approval.
3. Create a new feature branch from the latest `main` and switch to it before writing any code. Always include the Linear ticket number after `feature/`:
   ```
   git fetch origin
   git checkout -b feature/HAB-XX-<short-description> origin/main
   ```
   If the branch already exists, rebase it onto `origin/main` before writing any code (`git rebase origin/main`). This ensures the PR diff contains only the new work.
   **Before merging**, always rebase the branch onto the latest `origin/main` again (`git fetch origin && git rebase origin/main`) so the branch is up to date and the merge lands cleanly on the current tip.
4. Invoke the `validate` skill to generate integration tests from the ticket spec:

   ```
   Invoke the validate skill for HAB-XX: <issue title>
   ```

   The skill reads the ticket (and any `plan` comment), drafts `integration_test/` files using `AppHarness`, waits for approval, and writes the approved tests. Tests are intentionally red at this point — no production code exists yet. Pure infrastructure or CI-only changes with no user-facing flows may skip this step.
5. For features with user-visible screens or interactions: draft widget tests before writing production code:
   - Create new widget tests covering each new screen and key user flow (swiping, tapping, navigation, locale changes, auto-advance, etc.).
   - Update any existing widget tests that the new screens or UI changes will affect.
   - Present all new and updated widget test files to the user and wait for approval.
   - Do not continue to step 6 until the user approves the widget tests.
6. Write failing unit tests that describe the expected business logic behaviour.
7. Implement the minimum code to make the tests pass.
   **Opportunistic changes during implementation:** If an idea arises to modify existing or in-flight functionality (a bug fix, an edge-case handler, a UX improvement), write the integration test for that change first before touching production code. Never modify observable behaviour without a covering integration test.
8. Refactor if needed.
9. Run `flutter test` and `flutter analyze` — fix **all** test failures and analyzer warnings/errors before proceeding. A clean analyzer output (`No issues found`) is required before committing; do not leave warnings unresolved on the assumption they are pre-existing.
10. Apply formatting in a dedicated commit **before** the functional commit: run `dart format -l 120 lib/ test/ integration_test/` and, if any files changed, stage and commit them separately with a `style:` prefix (e.g. `style: apply dart format`). This keeps style changes reviewable in isolation from logic changes.
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
    - Invoke both review skills simultaneously once the PR is open (they are independent — launch them simultaneously):
      - `review-architecture` for architectural review: `Invoke the review-architecture skill for PR #<number>`.
      - `audit-code` for runtime/launch/migration review: `Invoke the audit-code skill for PR #<number>`.
    - Move the Linear ticket to **In Review**.
    - Inform the user of the PR URL.
15. Remind the user to compact the context after each commit to keep the conversation lean.
16. When the user approves the PR, run the full integration test suite locally before invoking ship:
    ```
    flutter test integration_test/ -d <device-id>
    ```
    All integration tests must be green. Do not invoke `ship` if any integration test is failing. Once they pass, invoke the `ship` skill:
    ```
    Invoke the ship skill for PR #<number>
    ```
    The skill moves the Linear ticket to **In QA**, adds a CHANGELOG entry, regenerates BACKLOG.md, bumps `pubspec.yaml` version, commits onto the feature branch, pushes, and merges. No separate approval is needed for the version bump.
17. Clear the context after the PR is merged. The ticket stays **In QA** until the user confirms QA has passed — at that point the user moves it to **Done** in Linear manually.
18. A new ticket may be picked up while the previous one is In QA.
