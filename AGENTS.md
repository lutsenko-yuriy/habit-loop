# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Habit Loop app ("Habit Loop") targeting mobile platforms (iOS, Android). Flutter Framework, Dart SDK ^3.6.0. Available in English, French, German, and Russian.

As a person who wants to establish a new habit (e.g., meditate or jog) I want to create a pact to "show up" so that I could either build a habit when the pact is over, correct something after the pact is over and start again or realize that the habit is not mine. This is what Habit Loop app does.

Full product specifications: docs/PRODUCT_SPEC.md

## Documentation

| File | Purpose |
|---|---|
| docs/PRODUCT_SPEC.md | What the app does — feature requirements |
| docs/ARCHITECTURE.md | How the code is organised — layers, directory structure, dependencies |
| docs/GLOSSARY.md | Ubiquitous language — canonical domain terms and known aliases |
| docs/BACKLOG.md | Known issues and remaining work not yet released |
| docs/CHANGELOG.md | Released version history |
| docs/VERSIONING.md | Version numbering rules and CI/CD pipeline |
| docs/ANALYTICS_EVENTS.md | Analytics event catalogue — events, screen views, and their properties |
| docs/CODE_STYLE.md | Code style rules — formatting, linting, comment hygiene |
| docs/MODEL_TIERS.md | Effort Tier and Reasoning Depth vocabulary; active model → tier mapping |
| docs/experiments/README.md | Experiment registry index — one `.md` file per experiment, tracking hypothesis, metrics, and decision |
| CLAUDE.local.md | Local machine settings (Flutter binary path, Linear MCP auth, active communication style) — gitignored, never commit (contains API keys) |
| skills/configure/calibrate/SKILL.md | One-time setup: propose and approve the model → tier mapping |
| skills/configure/skill-creator/SKILL.md | Create a new skill from scratch (guided wizard), or refactor an existing skill into lean SKILL.md + resource files |
| skills/configure/style/SKILL.md | Switch communication style: DETAILED, CONCISE, or SCHEMATIC |
| skills/manage/summarize/SKILL.md | Session-start: fetch and display the backlog |
| skills/manage/ship/SKILL.md | Post-merge housekeeping: close issues, update docs, bump version, merge |
| skills/design/analyze/SKILL.md | Analytics planning: identify events and screen views for a feature |
| skills/design/plan/SKILL.md | Implementation planning: structured plan from a Linear issue |
| skills/design/experiment/SKILL.md | Experiment design: hypothesis, metrics, feature flag, registry entry |
| skills/build/implement/SKILL.md | TDD implementation and PR |
| skills/run/android/SKILL.md | Start the app on Android (physical device → running emulator → launch AVD) |
| skills/run/ios/SKILL.md | Start the app on iOS (physical device → booted Simulator → boot Simulator) |
| skills/verify/review/SKILL.md | Architectural PR review |
| skills/verify/audit/SKILL.md | Runtime and migration PR review |

## Slash commands

Every skill is registered as a Claude Code slash command via a thin stub in `.claude/commands/`. Type `/` in Claude Code to see the full list.

| Command | Skill | Usage |
|---|---|---|
| `/ship` | manage/ship | `/ship PR #N` |
| `/summarize` | manage/summarize | `/summarize` |
| `/review` | verify/review | `/review PR #N` |
| `/audit` | verify/audit | `/audit PR #N` |
| `/plan` | design/plan | `/plan HAB-XX: <title>` |
| `/analyze` | design/analyze | `/analyze HAB-XX: <title>` |
| `/experiment` | design/experiment | `/experiment <hypothesis>` |
| `/implement` | build/implement | `/implement HAB-XX: <title>` |
| `/calibrate` | configure/calibrate | `/calibrate` |
| `/skill-creator` | configure/skill-creator | `/skill-creator skills/<path>` or `/skill-creator all` |
| `/style` | configure/style | `/style CONCISE` |
| `/ios` | run/ios | `/ios` |
| `/android` | run/android | `/android` |

## Architecture

Vertical-slice architecture with **Riverpod** (state management + DI) and **sqflite** (local storage). Details and directory layout: docs/ARCHITECTURE.md.

## Common Commands

Use the Flutter binary path from `CLAUDE.local.md` (it is not on the default shell PATH).

- **Run app:** `flutter run` (add `-d ios`, `-d android`, etc. for specific platforms)
- **Analyze:** `flutter analyze`
- **Run all tests:** `flutter test`
- **Run a single test file:** `flutter test test/path/to/test_file.dart`
- **Run integration tests:** `flutter test integration_test/ -d <device-id>` (requires a running simulator or physical device — start one first with `/ios` or `/android`)
- **Get dependencies:** `flutter pub get`
- **Regenerate localizations:** `flutter gen-l10n` — **must be run after editing any `lib/l10n/*.arb` file**; the generated `lib/l10n/generated/` files are in `.gitignore` and are not committed. CI runs this step automatically before tests and builds.
- **Format:** `dart format -l 120 lib/ test/ integration_test/`

## Code style

See `docs/CODE_STYLE.md`. Flutter style guide is the base; the document adds project-specific formatting, linting, and comment rules.

## Versioning

Update `pubspec.yaml` version name (`X.Y.Z`) whenever a new `CHANGELOG.md` entry is added — no separate approval needed.
CI handles build numbers automatically — do not touch.
Details: @docs/VERSIONING.md

## Session start

At the beginning of every new session, before doing anything else:

1. Ensure the Linear MCP is authenticated. If `mcp__linear__*` tools are unavailable, use `/mcp` to trigger the OAuth flow — see `CLAUDE.local.md` for setup notes.
2. Check `CLAUDE.local.md` for an `## Active communication style` section and silently load that style (see `skills/configure/style/`). Default to DETAILED if absent.
3. Invoke the `summarize` skill: `Invoke the summarize skill to present the current backlog from Linear`.
4. The skill will summarise what has been done and what is remaining, then ask *"What goes into the next release?"*.
5. Wait for the user's answer before proceeding.

## Workflow

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

1. For features with user-facing screens/interactions, invoke `analyze` first and wait for approval.
2. For large changes, invoke `plan` and wait for plan approval.
3. Create a new feature branch from the latest `main` and switch to it before writing any code. Always include the Linear ticket number after `feature/`:
   ```
   git fetch origin
   git checkout -b feature/HAB-XX-<short-description> origin/main
   ```
   If the branch already exists, rebase it onto `origin/main` before writing any code (`git rebase origin/main`). This ensures the PR diff contains only the new work.
   **Before merging**, always rebase the branch onto the latest `origin/main` again (`git fetch origin && git rebase origin/main`) so the branch is up to date and the merge lands cleanly on the current tip.
4. Write integration tests that describe the end-to-end behaviour being added or changed:
   - For any feature with user-visible screens or flows, create one or more test files in `integration_test/` using `AppHarness` (see `integration_test/harness.dart`).
   - Tests should cover the happy path and the most critical failure paths (e.g. missing data, deleted entities, navigation back-stack correctness).
   - Present all new integration test files to the user and wait for approval before writing any production code.
   - Pure infrastructure or CI-only changes with no user-facing flows may skip this step.
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
    **Release note tagging (enforced by CI — `scripts/lint_changelog.py` runs on every PR):**
    Every new `## [X.Y.Z]` CHANGELOG entry MUST contain at least one of:
    - `- [user-none]` — the entire entry is internal-only (CI fixes, refactors, tooling). Use this as a single sentinel line; all other bullets in the entry should use `[non-user]`.
    - `- [user] <plain English>` — one or more user-facing bullets in plain English (no ticket refs, no code identifiers). Only these lines appear in Firebase App Distribution release notes.
    Developer-only bullets within a tagged entry must be prefixed with `- [non-user] …` so the distinction is explicit.
    **Never commit a CHANGELOG entry that has no `[user]` bullet and no `[user-none]` sentinel — CI will fail.**
13. Commit all changes with a descriptive message.
14. Push to the remote and open a PR — all in parallel:
    - Push the branch to the remote.
    - Open a PR.
    - Invoke both review skills simultaneously once the PR is open (they are independent — launch them simultaneously):
      - `review` for architectural review: `Invoke the review skill for PR #<number>`.
      - `audit` for runtime/launch/migration review: `Invoke the audit skill for PR #<number>`.
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

## Experiments

Product experiments are tracked in `docs/experiments/`. The registry README (`docs/experiments/README.md`) contains the index table; each individual experiment has its own file named `EXP-NNN-<short-name>.md` following `docs/experiments/TEMPLATE.md`.

When starting an experiment:
1. Invoke the `experiment` skill with a hypothesis description: `Invoke the experiment skill for: <hypothesis>`.
2. The skill will assign the next EXP-NNN ID automatically, draft the spec, wait for approval, then create the file and update the registry.

When an experiment concludes (status changes to `won`, `lost`, or `abandoned`):
1. Update the experiment file with the final decision and learnings.
2. Update the index row in `docs/experiments/README.md` with the primary metric result and decision date.

The registry must be kept up to date so experiment outcomes are never lost.
