# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Habit Loop app ("Habit Loop") targeting mobile platforms (iOS, Android). Flutter Framework, Dart SDK ^3.6.0. Available in English, French, German, and Russian.

As a person who wants to establish a new habit (e.g., meditate or jog) I want to create a pact to "show up" so that I could either build a habit when the pact is over, correct something after the pact is over and start again or realize that the habit is not mine. This is what Habit Loop app does.

Full product specifications: @docs/PRODUCT_SPEC.md

## Documentation

| File | Purpose |
|---|---|
| @docs/PRODUCT_SPEC.md | What the app does — feature requirements |
| @docs/ARCHITECTURE.md | How the code is organised — layers, directory structure, dependencies |
| @docs/BACKLOG.md | Known issues and remaining work not yet released |
| @docs/CHANGELOG.md | Released version history |
| @docs/VERSIONING.md | Version numbering rules and CI/CD pipeline |
| @docs/ANALYTICS_EVENTS.md | Analytics event catalogue — events, screen views, and their properties |
| @docs/MODEL_TIERS.md | Effort Tier and Reasoning Depth vocabulary; active model → tier mapping |
| @docs/experiments/README.md | Experiment registry index — one `.md` file per experiment, tracking hypothesis, metrics, and decision |
| CLAUDE.local.md | Local machine settings (Flutter binary path, Linear MCP auth, active communication style) — not committed |
| skills/configure/calibrate/SKILL.md | One-time setup: propose and approve the model → tier mapping |
| skills/configure/style/SKILL.md | Switch communication style: DETAILED, CONCISE, or SCHEMATIC |
| skills/manage/summarize/SKILL.md | Session-start: fetch and display the backlog |
| skills/manage/ship/SKILL.md | Post-merge housekeeping: close issues, update docs, bump version, merge |
| skills/design/analyze/SKILL.md | Analytics planning: identify events and screen views for a feature |
| skills/design/plan/SKILL.md | Implementation planning: structured plan from a Linear issue |
| skills/design/experiment/SKILL.md | Experiment design: hypothesis, metrics, feature flag, registry entry |
| skills/build/implement/SKILL.md | TDD implementation and PR |
| skills/verify/review/SKILL.md | Architectural PR review |
| skills/verify/audit/SKILL.md | Runtime and migration PR review |

## Architecture

Vertical-slice architecture with **Riverpod** (state management + DI) and **sqflite** (local storage). Details and directory layout: @docs/ARCHITECTURE.md.

## Common Commands

Use the Flutter binary path from `CLAUDE.local.md` (it is not on the default shell PATH).

- **Run app:** `flutter run` (add `-d ios`, `-d android`, etc. for specific platforms)
- **Analyze:** `flutter analyze`
- **Run all tests:** `flutter test`
- **Run a single test file:** `flutter test test/path/to/test_file.dart`
- **Get dependencies:** `flutter pub get`
- **Regenerate localizations:** `flutter gen-l10n` — **must be run after editing any `lib/l10n/*.arb` file**; the generated `lib/l10n/generated/` files are in `.gitignore` and are not committed. CI runs this step automatically before tests and builds.
- **Format:** `dart format -l 120 lib/ test/`

## Code style

By default as defined at [the Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md).

## Linting

Uses `package:flutter_lints` (configured in `analysis_options.yaml`).

## Versioning

Update `pubspec.yaml` version name (`X.Y.Z`) whenever a new `CHANGELOG.md` entry is added — no separate approval needed.
CI handles build numbers automatically — do not touch.
Details: @docs/VERSIONING.md

## Session start

At the beginning of every new session, before doing anything else:

1. Ensure the Linear MCP is authenticated. If `mcp__linear__*` tools are unavailable, use `/mcp` to trigger the OAuth flow — see `CLAUDE.local.md` for setup notes.
2. Check `CLAUDE.local.md` for an `## Active communication style` section and silently load that style (see `styles/`). Default to DETAILED if absent.
3. Invoke the `summarize` skill: `Invoke the summarize skill to present the current backlog from Linear`.
4. The skill will summarise what has been done and what is remaining, then ask *"What goes into the next release?"*.
5. Wait for the user's answer before proceeding.

## Workflow

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

**Only one ticket may be in progress at a time.** Before picking up any new ticket, check Linear to confirm no other ticket is currently in progress.

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
4. Write failing tests that describe the expected behaviour.
5. Implement the minimum code to make the tests pass.
6. Refactor if needed.
7. Run `flutter test` and `flutter analyze` — fix **all** test failures and analyzer warnings/errors before proceeding. A clean analyzer output (`No issues found`) is required before committing; do not leave warnings unresolved on the assumption they are pre-existing.
8. Apply formatting in a dedicated commit **before** the functional commit: run `dart format -l 120 lib/ test/` and, if any files changed, stage and commit them separately with a `style:` prefix (e.g. `style: apply dart format`). This keeps style changes reviewable in isolation from logic changes.
9. Update documentation if affected by the changes:
    - `CLAUDE.md` — architecture, conventions, or workflow changed
    - `@docs/PRODUCT_SPEC.md` — functionality added, removed, or changed
    - `@docs/ARCHITECTURE.md` — code structure or dependencies changed
    - `@docs/VERSIONING.md` — CI/CD or versioning process impacted
10. **Keep `pubspec.yaml` version in sync with `docs/CHANGELOG.md`.** Before committing, check that the version name (`X.Y.Z`) in `pubspec.yaml` matches the latest `[X.Y.Z]` entry in `CHANGELOG.md`. If a new changelog entry was added in this PR, update `pubspec.yaml` accordingly. Do not touch the build number — CI manages it.
11. Commit all changes with a descriptive message.
12. Push to the remote and open a PR — all in parallel:
    - Push the branch to the remote.
    - Open a PR.
    - Invoke both review skills simultaneously once the PR is open (they are independent — launch them simultaneously):
      - `review` for architectural review: `Invoke the review skill for PR #<number>`.
      - `audit` for runtime/launch/migration review: `Invoke the audit skill for PR #<number>`.
    - Inform the user of the PR URL.
13. Remind the user to compact the context after each commit to keep the conversation lean.
14. When the user approves the PR, invoke the `ship` skill **before merging**:
    ```
    Invoke the ship skill for PR #<number>
    ```
    The skill closes the Linear issues, adds a CHANGELOG entry, regenerates BACKLOG.md, bumps `pubspec.yaml` version, commits onto the feature branch, pushes, and merges. No separate approval is needed for the version bump.
15. Clear the context after the PR with the changes is merged.

## Experiments

Product experiments are tracked in `docs/experiments/`. The registry README (`docs/experiments/README.md`) contains the index table; each individual experiment has its own file named `EXP-NNN-<short-name>.md` following `docs/experiments/TEMPLATE.md`.

When starting an experiment:
1. Invoke the `experiment` skill with a hypothesis description: `Invoke the experiment skill for: <hypothesis>`.
2. The skill will assign the next EXP-NNN ID automatically, draft the spec, wait for approval, then create the file and update the registry.

When an experiment concludes (status changes to `won`, `lost`, or `abandoned`):
1. Update the experiment file with the final decision and learnings.
2. Update the index row in `docs/experiments/README.md` with the primary metric result and decision date.

The registry must be kept up to date so experiment outcomes are never lost.
