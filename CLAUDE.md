# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Habit Loop app ("Habit Loop") targeting mobile platforms (iOS, Android). Flutter Framework, Dart SDK ^3.6.0. Available in English, French, and German.

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
| CLAUDE.local.md | Local machine settings (Flutter binary path, etc.) — not committed |
| .claude/agents/code-reviewer.md | PR review agent — invoked automatically in workflow step 14 |

## Architecture

Vertical-slice architecture with **Riverpod** (state management + DI) and **sqflite** (local storage). Details and directory layout: @docs/ARCHITECTURE.md.

## Common Commands

Use the Flutter binary path from `CLAUDE.local.md` (it is not on the default shell PATH).

- **Run app:** `flutter run` (add `-d ios`, `-d android`, etc. for specific platforms)
- **Analyze:** `flutter analyze`
- **Run all tests:** `flutter test`
- **Run a single test file:** `flutter test test/path/to/test_file.dart`
- **Get dependencies:** `flutter pub get`
- **Regenerate localizations:** `flutter gen-l10n`

## Code style

By default as defined at [the Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md).

## Linting

Uses `package:flutter_lints` (configured in `analysis_options.yaml`).

## Versioning

Version bumps in pubspec.yaml require user approval before any change.
CI handles build numbers automatically — do not touch.
Details: @docs/VERSIONING.md

## Session start

At the beginning of every new session, before doing anything else:

1. Read `@docs/CHANGELOG.md` (released versions) and `@docs/BACKLOG.md` (known issues and remaining work).
2. Summarise to the user what has already been done (latest release) and what is still remaining (backlog).
3. Ask the user: *"What goes into the next release?"* and wait for their answer before proceeding.

## Workflow

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

**For large changes** (spanning multiple files, introducing new domain entities, new dependencies, or architectural shifts): present an implementation plan to the user **before writing any code**. The plan should cover:

- New packages / dependencies
- New models and classes
- Changes to existing classes
- UI changes (for each platform)
- Test strategy
- Implementation order broken into phases

After that, wait for the user to review and approve (or adjust) the plan before proceeding.

1. For large changes, present the implementation plan and wait for approval.
2. Create a new feature branch (`git checkout -b feature/<name>`) and switch to it before writing any code.
3. Write failing tests that describe the expected behaviour.
4. Implement the minimum code to make the tests pass.
5. Refactor if needed.
6. Run `flutter test` and `flutter analyze` — fix any failures before proceeding.
7. Update documentation if affected by the changes:
    - `CLAUDE.md` — architecture, conventions, or workflow changed
    - `@docs/PRODUCT_SPEC.md` — functionality added, removed, or changed
    - `@docs/ARCHITECTURE.md` — code structure or dependencies changed
    - `@docs/VERSIONING.md` — CI/CD or versioning process impacted
8. Commit all changes with a descriptive message.
9. Launch the app on both platforms for a smoke test using the Flutter binary from `CLAUDE.local.md`:
    ```
    flutter run -d ios
    flutter run -d android
    ```
    Run each in the background (`run_in_background: true`) so both start simultaneously. Wait for the user to confirm the app looks correct on both platforms before proceeding.
10. Push to the remote.
11. Open a PR and request a review:
    - Check whether a `code-reviewer` agent exists in `.claude/agents/code-reviewer.md`.
    - If it does, invoke it immediately by passing it the PR number: `Use the code-reviewer agent to review PR #<number>`.
    - If no such agent exists, request a review from the user directly.
12. Remind the user to compact the context after each commit to keep the conversation lean.
13. After the PR is merged:
    - Update `@docs/CHANGELOG.md`: add a new version section (e.g., `[0.2.0]`) with the date and PR reference describing what was delivered.
    - Update `@docs/BACKLOG.md`: remove completed items from **Remaining work**; add any new issues discovered during the work to **Issues**.
14. Clear the context after the PR with the changes is merged.
