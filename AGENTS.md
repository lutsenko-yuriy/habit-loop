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
| @docs/ANALYTICS_EVENTS.md | Analytics event catalogue — events, screen views, and their properties |
| CLAUDE.local.md | Local machine settings (Flutter binary path, Linear MCP auth, etc.) — not committed |
| .claude/agents/code-reviewer.md | PR review agent — invoked automatically in workflow step 11 |
| .claude/agents/product-owner.md | Product Owner agent — invoked at session start, for analytics planning, and after PR merge |
| .claude/agents/tech-lead.md | Tech Lead agent — invoked for large changes to produce an implementation plan before coding starts |
| .claude/agents/developer.md | Developer agent — invoked to implement a Tech Lead work unit following TDD |

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

1. Ensure the Linear MCP is authenticated. If `mcp__linear__*` tools are unavailable, use `/mcp` to trigger the OAuth flow — see `CLAUDE.local.md` for setup notes.
2. Invoke the `product-owner` agent: `Use the product-owner agent to present the current backlog from Linear`.
3. The Product Owner agent will summarise what has been done and what is remaining, then ask *"What goes into the next release?"*.
4. Wait for the user's answer before proceeding.

## Workflow

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

**For features with user-visible screens or interactions**: invoke the `product-owner` agent first for analytics planning before the Tech Lead:

```
Use the product-owner agent to plan analytics for HAB-XX: <issue title>
```

The Product Owner will propose which events and screen views to track, flag any PII concerns, update `docs/ANALYTICS_EVENTS.md`, and wait for approval. Pure infrastructure or CI changes with no user-facing screens skip this step.

**For large changes** (spanning multiple files, introducing new domain entities, new dependencies, or architectural shifts): invoke the `tech-lead` agent to produce the implementation plan **before writing any code**:

```
Use the tech-lead agent to plan HAB-XX: <issue title>
```

The Tech Lead will produce a structured plan (dependencies, models, UI changes, test strategy, ordered phases, Developer work units) and wait for the user to approve or adjust it.

1. For features with user-facing screens/interactions, invoke the product-owner agent for analytics planning first and wait for approval.
2. For large changes, invoke the tech-lead agent and wait for plan approval.
3. Create a new feature branch (`git checkout -b feature/HAB-XX-<short-description>`) and switch to it before writing any code. Always include the Linear ticket number after `feature/`.
4. Write failing tests that describe the expected behaviour.
5. Implement the minimum code to make the tests pass.
6. Refactor if needed.
7. Run `flutter test` and `flutter analyze` — fix any failures before proceeding.
8. Apply formatting in a dedicated commit **before** the functional commit: run `dart format lib/ test/` and, if any files changed, stage and commit them separately with a `style:` prefix (e.g. `style: apply dart format`). This keeps style changes reviewable in isolation from logic changes.
9. Update documentation if affected by the changes:
    - `CLAUDE.md` — architecture, conventions, or workflow changed
    - `@docs/PRODUCT_SPEC.md` — functionality added, removed, or changed
    - `@docs/ARCHITECTURE.md` — code structure or dependencies changed
    - `@docs/VERSIONING.md` — CI/CD or versioning process impacted
10. Commit all changes with a descriptive message.
11. Launch the app on both platforms for a smoke test using the Flutter binary from `CLAUDE.local.md`:
    ```
    flutter run -d ios
    flutter run -d android
    ```
    Run each in the background (`run_in_background: true`) so both start simultaneously. Wait for the user to confirm the app looks correct on both platforms before proceeding.
12. Push to the remote.
13. Open a PR and request reviews in parallel (both agents are independent — launch them simultaneously):
    - If `.claude/agents/tech-lead.md` exists, invoke it for an architectural review: `Use the tech-lead agent to review PR #<number>`.
    - If `.claude/agents/code-reviewer.md` exists, invoke it for a runtime/launch/migration review: `Use the code-reviewer agent to review PR #<number>`.
    - If neither agent exists, request a review from the user directly.
14. Remind the user to compact the context after each commit to keep the conversation lean.
15. When the user approves the PR:
    - Invoke the `product-owner` agent: `Use the product-owner agent to close the approved PR's Linear issues, regenerate BACKLOG.md and CHANGELOG.md, and merge the PR`.
16. Clear the context after the PR with the changes is merged.
