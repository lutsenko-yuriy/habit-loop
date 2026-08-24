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
| docs/VERSIONING.md | Version numbering rules — semver, build numbers, CHANGELOG tags, release notes |
| docs/CI_PIPELINE.md | CI/CD pipeline — job graph, manual dispatch, TestFlight distribution, secrets/variables |
| docs/FEATURE_TOGGLES.md | Firebase Remote Config kill-switch flags — catalogue of toggles and their effects |
| docs/ANALYTICS_EVENTS.md | Analytics event catalogue — events, screen views, and their properties |
| docs/CODE_STYLE.md | Code style rules — formatting, linting, comment hygiene |
| docs/LICENSING.md | Current licence (MIT) — cites ADR-0001 for the decision record |
| docs/MODEL_TIERS.md | Effort Tier and Reasoning Depth vocabulary; active model → tier mapping |
| docs/experiments/README.md | Experiment registry index — one `.md` file per experiment, tracking hypothesis, metrics, and decision |
| docs/knowledge/decisions/README.md | ADR registry index — one `.md` file per standing decision, discoverable independent of the ticket that produced it |
| docs/CONSTRAINTS.md | Standing project constraints — reference when evaluating trade-offs in research tickets |
| docs/workflows/FEATURE.md | Step-by-step feature development workflow — TDD cycle, branching, PR, ship, and ticket state rules |
| docs/workflows/TROUBLESHOOT.md | Reactive workflow for bugs, CI failures, and infrastructure issues — investigate, ticket, fix, ship |
| docs/workflows/RESEARCH.md | Step-by-step workflow for research-only tickets — alternatives survey, constraint evaluation, debrief |
| docs/workflows/POSTMORTEM.md | Post-fix root-cause investigation workflow — reconstructing when/why a shipped bug was introduced, after `docs/workflows/TROUBLESHOOT.md` produced the fix |
| docs/workflows/MULTI_WU.md | Multi-WU ticket appendix to `FEATURE.md` — WU-splitting guidelines, pre-implementation WU types, branch/PR-per-WU rules, `[wip]` tagging, WU cycle |
| docs/knowledge/README.md | Project knowledge base — vault layout, per-ticket file format, how `/note` and `/debrief` write entries |
| docs/knowledge/notes/INDEX.md | Generated tagged table of contents over `docs/knowledge/notes/` — regenerate via `scripts/notes/index.py`, do not edit by hand (HAB-221) |
| skills/shared/*.md | Shared skill fragments (`project-config.md`, `decision-guidelines.md`, `dialog-guidelines.md`, `pm-tool-mapping.md`, `linear-efficiency.md`) — `@`-included by individual skills as needed; not meant to be read standalone |
| CLAUDE.local.md | Local machine settings (Flutter binary path, Linear MCP auth, active communication style) — gitignored, never commit (contains API keys) |

## Skills

Every skill is registered as a Claude Code slash command via a thin stub in `.claude/commands/`. Type `/` in Claude Code to see the full list.

| Command | Skill | Purpose | Usage |
|---|---|---|---|
| `/calibrate` | configure/calibrate | One-time setup: propose and approve the model → tier mapping | `/calibrate` |
| `/skill-creator` | configure/skill-creator | Create a new skill from scratch (guided wizard), or refactor an existing skill into lean SKILL.md + resource files | `/skill-creator skills/<path>` or `/skill-creator all` |
| `/style` | configure/style | Switch communication style: DETAILED, CONCISE, or SCHEMATIC | `/style CONCISE` |
| `/summarize` | manage/summarize | Session-start: fetch and display the backlog | `/summarize` |
| `/ship` | manage/ship | Post-merge housekeeping: close issues, update docs, bump version, merge | `/ship PR #N` |
| `/draft-release-notes` | manage/draft-release-notes | Draft [user] bullets for the current changes, separately from the technical HAB-XX bullet | `/draft-release-notes [PR #N \| HAB-XX]` |
| `/debrief` | manage/debrief | Post-ticket retrospective: structured dialog → workflow improvements + knowledge base entry | `/debrief HAB-XX` |
| `/note` | manage/note | Capture a quick observation mid-session into a ticket's knowledge-base note | `/note [HAB-XX:] <free-form text>` |
| `/cleanup-firebase` | manage/cleanup-firebase | Delete old Firebase App Distribution builds locally, keeping the N most recent per platform | `/cleanup-firebase [N] [--dry-run]` |
| `/dead-code-check` | manage/dead-code-check | Advisory dead-code detector — surfaces orphaned l10n keys, analytics events, test files, and handler files | `/dead-code-check` |
| `/checkup` | manage/checkup | Two-tier periodic code-quality checkup (light monthly / heavy quarterly) — walks the 8 non-mechanical dimensions, fixes inline or writes findings to docs/knowledge/checkups/ with deadlines | `/checkup [light|heavy|status]` |
| `/analyze` | design/analyze | Analytics planning: identify events and screen views for a feature | `/analyze HAB-XX: <title>` |
| `/brief` | design/brief | Feature intake: clarifying dialog → scoped Linear ticket + glossary update | `/brief` |
| `/plan` | design/plan | Implementation planning: structured plan from a Linear issue | `/plan HAB-XX: <title>` |
| `/experiment` | design/experiment | Experiment design: hypothesis, metrics, feature flag, registry entry | `/experiment <hypothesis>` |
| `/research` | design/research | Literature research: thesis/antithesis/synthesis for a claim, or a scoping map for a bare topic — cited evidence, single synthesis pass | `/research <claim or topic>` |
| `/implement` | build/implement | TDD implementation and PR | `/implement HAB-XX: <title>` |
| `/android` | run/android | Start the app on Android (physical device → running emulator → launch AVD) | `/android` |
| `/ios` | run/ios | Start the app on iOS (physical device → booted Simulator → boot Simulator) | `/ios` |
| `/run-scenarios` | run/run-scenarios | Run integration test scenarios before merging — finds device, runs flutter test integration_test/, reports pass/fail | `/run-scenarios` or `/run-scenarios HAB-XX` |
| `/draft-scenarios` | verify/draft-scenarios | Pre-implementation scenario drafting: write red scenarios (integration tests) from the ticket spec | `/draft-scenarios HAB-XX: <title>` |
| `/review-architecture` | verify/review | Architectural PR review | `/review-architecture PR #N` |
| `/audit-code` | verify/audit | Runtime and migration PR review | `/audit-code PR #N` |

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

Update `pubspec.yaml` version name (`X.Y.Z`) whenever a new `docs/CHANGELOG.md` entry carrying a `[user]`/`[app]` tag is added — no separate approval needed. Entries without one land under `## [Unreleased]` instead and never bump the version (HAB-185).
CI handles build numbers automatically — do not touch.
Details: @docs/VERSIONING.md

## Session start

At the beginning of every new session, before doing anything else, this checklist runs in two parts:

**Automated by the `SessionStart` hook** (`.claude/hooks/session_start.sh`, matcher `startup` only — deliberately excluding `resume` so reattaching to an in-progress ticket doesn't re-trigger the checklist mid-task — wired in `.claude/settings.local.json`, HAB-186). The hook injects steps 1-4 below as context automatically; Claude does not need to be told to run them. This section stays the source of truth for what the checklist does — the hook is just the trigger:

1. Ensure the Linear MCP is authenticated. If `mcp__linear__*` tools are unavailable, use `/mcp` to trigger the OAuth flow — see `CLAUDE.local.md` for setup notes.
2. Check `CLAUDE.local.md` for an `## Active communication style` section and silently load that style (see `skills/configure/style/`). Default to DETAILED if absent.
3. Invoke the `summarize` skill: `Invoke the summarize skill to present the current backlog from Linear`.
4. Run `scripts/checkup/due.py --format=session`. If it reports a tier as due, recommend running `/checkup` before picking up a new ticket, alongside the backlog summary.

**Performed by the agent itself**, following on from the hook-injected context above:

5. The skill will summarise what has been done and what is remaining, then ask *"What goes into the next release? Pick an existing ticket or describe something new."*.
6. Wait for the user's answer before proceeding. If the user wants to describe something new, invoke the `brief` skill before any planning begins.

## Workflow

@docs/workflows/FEATURE.md

Reactive work (bugs, CI failures, regressions, infrastructure breakage) uses
`docs/workflows/TROUBLESHOOT.md` instead of the above. Research-only tickets use
`docs/workflows/RESEARCH.md`. Post-fix root-cause investigation (reconstructing when/why a
shipped bug was introduced, after `TROUBLESHOOT.md` produced the fix) uses
`docs/workflows/POSTMORTEM.md`. Read whichever one applies by path when its trigger condition
is met — they are not preloaded every session.

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
