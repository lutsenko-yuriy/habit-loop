---
name: implement
effort: FOCUSED
reasoning: TACTICAL
tools: linear,github,files
max_turns: 60
output_style: CONCISE
description: Implement a work unit from an approved plan. Given a PM issue ID, fetches the plan comment, follows strict TDD (red → green → refactor), creates the feature branch, runs tests and linting, commits with a style-only commit first, pushes, and opens a PR. Does not merge — that is the `ship` skill's job.
---

@skills/shared/project-config.md
@skills/shared/decision-guidelines.md

---

## Setup (do this first, every time)

1. Read `CLAUDE.local.md` for local binary paths and environment settings. Use the Flutter binary path from there for every Flutter command — `flutter` is not on the default shell PATH.
2. Read `CLAUDE.md` and the architecture doc (path from project config) to orient yourself before touching any code.

---

## Workflow

### 1. Fetch the plan

Retrieve the issue details and find the implementation plan comment left by the `plan` skill:

Fetch the issue (PM mapping: **Fetch issue**), then list its comments (**List comments on issue**).

**Show the full issue description to the user** and ask: *"Does this match what you want to build? Any scope clarifications before I start?"* Wait for confirmation.

**If no approved plan comment exists — stop.** Report back:

> "No approved plan found on HAB-XX. Invoke the `plan` skill to produce and approve a plan before implementation can begin."

### 2. Move issue to In Progress

Move the issue to "In Progress" (PM mapping: **Move issue to state**).

### 3. Create or switch to the feature branch

Branch naming: `feature/HAB-XX-WUN-<short-description>` where N is the WU number from the plan (2–4 words, kebab-case).

**One WU = one branch = one PR. Never reuse a branch from a previous WU.**

Always create a new branch from the latest `main`:

```bash
git fetch origin
git checkout -b feature/HAB-XX-WUN-<short> origin/main
```

### 4. TDD cycle

**If this WU lists scenarios to make green:** before writing any production code, first replace the `// TODO:` comment stubs in those scenario files with actual `AppHarness` driver calls. This makes the scenarios compile and run red. Then proceed with the TDD cycle below to make them pass.

**Every `// TODO:` step within each scenario must be implemented — do not silently drop tail steps.** If a step genuinely cannot be implemented (e.g. requires disproportionate harness infrastructure), replace `// TODO:` with `// SKIP: <one-sentence reason>` and note it in the PR description. If a scenario's feature is dropped or deferred entirely during implementation, delete the whole `testWidgets` block before committing — do not leave empty stubs in main.

**Ambiguous UI spec during implementation:** if a sub-feature's design is described only by analogy ("like the rest of the app", "native style", etc.) with no concrete reference, stop before implementing it — ask for a visual reference or ASCII mockup, the same way `/brief` step 3.5 would. Iterating on vague specs is expensive.

@skills/build/implement/resources/tdd-cycle.md

### 4.1 Rework cycle checkpoint

A **rework cycle** is counted when the current WU approach is scrapped and restarted with a significantly different implementation — e.g. changing the widget tree structure, rewriting display logic, or switching the data model. Minor adjustments (padding, button colour, widget reordering) do not count.

At rework cycles 4, 7, 10, … (every 3rd cycle starting at 4), pause and ask:

> "It's taking more effort than expected. Do you want to continue? We can still simplify or drop this part."

Present three options: **Continue**, **Simplify** (scale back scope), **Drop** (remove this part entirely). If the user chooses Simplify or Drop, invoke the `plan` skill to update the plan before proceeding.

### 5. Schema / data migrations

@skills/build/implement/resources/migration-guide.md

### 6. Validate

Run both commands and fix every failure before proceeding:

```bash
flutter test
flutter analyze
```

(Use the Flutter binary path from `CLAUDE.local.md` for all Flutter commands.)

If `flutter pub get` is needed first (new dependency added), run it before the above:

```bash
flutter pub get
```

### 7. Localisation

If any user-visible strings were added:

1. Add keys to all four ARB files: `lib/l10n/app_en.arb`, `app_fr.arb`, `app_de.arb`, `app_ru.arb`.
2. Run `flutter gen-l10n` to regenerate the output.
3. Use the generated strings in the UI — never hardcode display text.

### 8. Request documentation updates

If your changes affect architecture or user-visible functionality, **do not update those docs yourself** — ask the orchestrator and wait for confirmation before proceeding:

- **Architecture doc** (path from project config) affected → ask orchestrator to invoke the `plan` skill to update it.
- **Product spec** (path from project config) affected → ask the orchestrator to update it directly (it is a markdown file in the repo, not owned by any specific skill) and wait for confirmation.

Both can be requested simultaneously. Only proceed after the orchestrator confirms those updates are committed.

Never update the backlog or changelog (paths from project config) — those are owned by the `ship` skill.

**PII constraint:** never pass user-entered text (habit names, notes, stop reasons) to `CrashlyticsService` — only field lengths, IDs, counts, and enum values. Local `logLocal()` calls may include more detail since logs never leave the device.

### 9. Format

Apply `dart format` in a **separate, formatting-only commit after all TDD micro-cycles, before opening the PR**:

```bash
dart format -l 120 lib/ test/
```

If any files changed, stage only those files and commit with a `style:` prefix:

```bash
git commit -m "style: apply dart format (HAB-XX)"
```

If no files changed, skip this step. Never mix formatting changes with functional changes in the same commit — keeping them separate makes the PR diff reviewable and ensures CI's `dart format -l 120 --set-exit-if-changed` check always passes.

**After every post-review fix commit**, re-run the same command over `lib/ test/ integration_test/` and add another `style:` commit if anything changed — do not skip this even for small, "obviously clean" fixes.

### 10. Push

All commits from TDD micro-cycles and the formatting commit already exist locally. Push them:

```bash
git push -u origin <branch-name>
```

### 11. PR size check

Before opening the PR, count the total LoC changed (excluding generated files):

```bash
git diff origin/main --stat -- ':(exclude)lib/l10n/generated/' | tail -1
```

If the total exceeds **400 LoC**, print a warning and ask the user to confirm before proceeding. Do not block — this is a soft gate.

### 12. Open a PR

@skills/build/implement/resources/pr-body-template.md

### 13. Move issue to In Review

Move the issue to "In Review" (PM mapping: **Move issue to state**).

### 14. Post the PR link to the issue

Post a comment on the issue with the PR URL (PM mapping: **Post comment on issue**):

```
PR opened: <PR URL>
```

### 15. Invoke reviews

Invoke both review skills simultaneously — they are independent and can run in parallel:

- **`review-architecture`** — architectural review (`/review-architecture PR #<N>`)
- **`audit-code`** — runtime/launch/migration review (`/audit-code PR #<N>`)

In Claude Code, call the `Skill` tool for both in a single response so they run in parallel. Via skill_router, run both scripts concurrently.

### 16. Report back

Return: what was built, PR number and URL, test results, any deviations from the plan and why.

---

## Constraints

- **TDD is non-negotiable.** Tests must be red before implementation starts.
- **No plan = no code.** Stop and escalate if the plan comment is missing.
- **Do not touch `pubspec.yaml` version fields** — version bumps are handled by the `ship` skill as part of post-merge housekeeping (no separate approval needed per `docs/VERSIONING.md`).
- **Do not merge** — that is the `ship` skill's responsibility.
- **Do not update `docs/ARCHITECTURE.md` or `docs/PRODUCT_SPEC.md` directly** — delegate as described in step 8.
- **Do not modify `skills/`** — skill files are owned by the meta-workflow, not by feature work.
- Fix all test and lint failures before opening the PR. Never leave the build red.
