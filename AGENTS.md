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
| docs/ARCHITECTURE.md | How the code is organised — layers, behaviour, dependencies |
| docs/GLOSSARY.md | Ubiquitous language — canonical domain terms and known aliases |
| docs/BACKLOG.md | Known issues and remaining work not yet released |
| docs/CHANGELOG.md | Released version history |
| docs/VERSIONING.md | Version numbering rules and CI/CD pipeline |
| docs/FEATURE_TOGGLES.md | Firebase Remote Config kill-switch flags — catalogue of toggles and their effects |
| docs/ANALYTICS_EVENTS.md | Analytics event catalogue — events, screen views, and their properties |
| docs/CODE_STYLE.md | Code style rules — formatting, linting, comment hygiene |
| docs/LICENSING.md | Licence decision record — dependency audit, WU1–WU3 research, WU4 pending |
| docs/MODEL_TIERS.md | Effort Tier and Reasoning Depth vocabulary; active model → tier mapping |
| docs/experiments/README.md | Experiment registry index — one `.md` file per experiment, tracking hypothesis, metrics, and decision |
| docs/knowledge/decisions/README.md | ADR registry index — one `.md` file per standing decision, discoverable independent of the ticket that produced it |
| docs/CONSTRAINTS.md | Standing project constraints — reference when evaluating trade-offs in research tickets |
| docs/FEATURE_WORKFLOW.md | Step-by-step feature development workflow — TDD cycle, branching, PR, ship, and ticket state rules |
| docs/TROUBLESHOOT_WORKFLOW.md | Reactive workflow for bugs, CI failures, and infrastructure issues — investigate, ticket, fix, ship |
| docs/RESEARCH_WORKFLOW.md | Step-by-step workflow for research-only tickets — alternatives survey, constraint evaluation, debrief |
| docs/knowledge/README.md | Project knowledge base — vault layout, per-ticket file format, how `/note` and `/debrief` write entries |
| CLAUDE.local.md | Local machine settings (Flutter binary path, Linear MCP auth, active communication style) — gitignored, never commit (contains API keys) |
| skills/configure/calibrate/SKILL.md | One-time setup: propose and approve the model → tier mapping |
| skills/configure/skill-creator/SKILL.md | Create a new skill from scratch (guided wizard), or refactor an existing skill into lean SKILL.md + resource files |
| skills/configure/style/SKILL.md | Switch communication style: DETAILED, CONCISE, or SCHEMATIC |
| skills/manage/summarize/SKILL.md | Session-start: fetch and display the backlog |
| skills/manage/ship/SKILL.md | Post-merge housekeeping: close issues, update docs, bump version, merge |
| skills/manage/debrief/SKILL.md | Post-ticket retrospective: structured dialog → workflow improvements + knowledge base entry |
| skills/manage/note/SKILL.md | Capture a quick observation mid-session into `docs/knowledge/notes/HAB-XX.md` |
| skills/manage/cleanup-firebase/SKILL.md | Delete old Firebase App Distribution builds locally, keeping the N most recent per platform |
| skills/manage/dead-code-check/SKILL.md | Advisory dead-code detector — surfaces orphaned l10n keys, analytics events, test files, and handler files |
| skills/design/analyze/SKILL.md | Analytics planning: identify events and screen views for a feature |
| skills/design/brief/SKILL.md | Feature intake: clarifying dialog → scoped Linear ticket + glossary update |
| skills/design/plan/SKILL.md | Implementation planning: structured plan from a Linear issue |
| skills/design/experiment/SKILL.md | Experiment design: hypothesis, metrics, feature flag, registry entry |
| skills/build/implement/SKILL.md | TDD implementation and PR |
| skills/run/android/SKILL.md | Start the app on Android (physical device → running emulator → launch AVD) |
| skills/run/ios/SKILL.md | Start the app on iOS (physical device → booted Simulator → boot Simulator) |
| skills/run/run-scenarios/SKILL.md | Run integration test scenarios before merging — finds device, runs flutter test integration_test/, reports pass/fail |
| skills/verify/draft-scenarios/SKILL.md | Pre-implementation scenario drafting: write red scenarios (integration tests) from the ticket spec |
| skills/verify/review/SKILL.md | Architectural PR review |
| skills/verify/audit/SKILL.md | Runtime and migration PR review |

## Slash commands

Every skill is registered as a Claude Code slash command via a thin stub in `.claude/commands/`. Type `/` in Claude Code to see the full list.

| Command | Skill | Usage |
|---|---|---|
| `/ship` | manage/ship | `/ship PR #N` |
| `/debrief` | manage/debrief | `/debrief HAB-XX` |
| `/summarize` | manage/summarize | `/summarize` |
| `/review-architecture` | verify/review | `/review-architecture PR #N` |
| `/audit-code` | verify/audit | `/audit-code PR #N` |
| `/plan` | design/plan | `/plan HAB-XX: <title>` |
| `/analyze` | design/analyze | `/analyze HAB-XX: <title>` |
| `/brief` | design/brief | `/brief` |
| `/experiment` | design/experiment | `/experiment <hypothesis>` |
| `/draft-scenarios` | verify/draft-scenarios | `/draft-scenarios HAB-XX: <title>` |
| `/implement` | build/implement | `/implement HAB-XX: <title>` |
| `/calibrate` | configure/calibrate | `/calibrate` |
| `/skill-creator` | configure/skill-creator | `/skill-creator skills/<path>` or `/skill-creator all` |
| `/style` | configure/style | `/style CONCISE` |
| `/ios` | run/ios | `/ios` |
| `/android` | run/android | `/android` |
| `/run-scenarios` | run/run-scenarios | `/run-scenarios` or `/run-scenarios HAB-XX` |
| `/cleanup-firebase` | manage/cleanup-firebase | `/cleanup-firebase [N] [--dry-run]` |
| `/dead-code-check` | manage/dead-code-check | `/dead-code-check` |
| `/note` | manage/note | `/note [HAB-XX:] <free-form text>` |

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
4. The skill will summarise what has been done and what is remaining, then ask *"What goes into the next release? Pick an existing ticket or describe something new."*.
5. Wait for the user's answer before proceeding. If the user wants to describe something new, invoke the `brief` skill before any planning begins.

## Workflow

@docs/FEATURE_WORKFLOW.md
@docs/TROUBLESHOOT_WORKFLOW.md

## Progress signaling

When a multi-step task is tracked via TaskList/TaskUpdate and you pause to ask the user a question, mark the current task back to `pending` rather than leaving it `in_progress` — a task still shown "in progress" while actually waiting on input reads as still-computing, not blocked. Say explicitly in the text that you're waiting for an answer.

## Experiments

Product experiments are tracked in `docs/experiments/`. The registry README (`docs/experiments/README.md`) contains the index table; each individual experiment has its own file named `EXP-NNN-<short-name>.md` following `docs/experiments/TEMPLATE.md`.

When starting an experiment:
1. Invoke the `experiment` skill with a hypothesis description: `Invoke the experiment skill for: <hypothesis>`.
2. The skill will assign the next EXP-NNN ID automatically, draft the spec, wait for approval, then create the file and update the registry.

When an experiment concludes (status changes to `won`, `lost`, or `abandoned`):
1. Update the experiment file with the final decision and learnings.
2. Update the index row in `docs/experiments/README.md` with the primary metric result and decision date.

The registry must be kept up to date so experiment outcomes are never lost.
