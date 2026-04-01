# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Habit Loop app ("Habit Loop") targeting mobile platforms (iOS, Android). Flutter Framework, Dart SDK ^3.6.0. Available in English, French, and German.

As a person who wants to establish a new habit (e.g., meditate or jog) I want to create a pact to "show up" so that I could either build a habit when the pact is over, correct something after the pact is over and start again or realize that the habit is not mine. This is what Habit Loop app does.

Full product specifications: @docs/PRODUCT_SPEC.md

## Architecture


The structure in general will be a vertical slice architecture, where each slice is a feature as defined in @docs/PRODUCT_SPEC.md.

Each vertical slice would have three layers: domain, data and UI.

Uses **Riverpod** for both state management and dependency injection. Uses **sqflite** for local storage.

The more detailed architecture you can find in @docs/ARCHITECTURE.md.

## Common Commands

- **Run app:** `flutter run` (add `-d ios`, `-d Android`, etc. for specific platforms)
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

## Workflow

Follow TDD: write or update tests **before** implementing the feature or fix. Red → Green → Refactor.

**For large changes** (spanning multiple files, introducing new domain entities, new dependencies, or architectural shifts): present an implementation plan to the user **before writing any code**. The plan should cover:

1. New packages / dependencies
2. New models and classes
3. Changes to existing classes
4. UI changes (for each platform)
5. Test strategy
6. Implementation order broken into phases

After that, wait for the user to review and approve (or adjust) the plan before proceeding.

1. For large changes, present the implementation plan and wait for approval.
2. Create a new feature branch (`git checkout -b feature/<name>`) and switch to it before writing any code.
3. Write failing tests that describe the expected behaviour.
3. Implement the minimum code to make the tests pass.
4. Refactor if needed.
5. Run `flutter test` and `flutter analyze` — fix any failures before proceeding.
6. Update this `CLAUDE.md` file if the architecture, UI, conventions or use cases changed.
7. If a functionality was added/removed/changed the required changes are made into `@docs/PRODUCT_SPEC.md`.
8. If a versioning and CI/CD process was somehow impacted `@docs/VERSIONING.md` gets modified.
9. If an architecture is changed the `@docs/ARCHITECTURE.md` gets modified.
10. Commit all changes with a descriptive message.
11. Push to the remote.
12. Remind the user to compact the context after each commit to keep the conversation lean.
13. Clear the context after the PR with the changes is merged.
