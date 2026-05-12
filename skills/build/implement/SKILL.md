---
name: implement
effort: FOCUSED
reasoning: TACTICAL
output_style: CONCISE
description: Implement a work unit from an approved plan. Given a PM issue ID, fetches the plan comment, follows strict TDD (red → green → refactor), creates the feature branch, runs tests and linting, commits with a style-only commit first, pushes, and opens a PR. Does not merge — that is the `ship` skill's job.
---

The project management tool is **Linear**. The Git host is **GitHub**. The issue identifier prefix is **HAB**.

Linear workspace IDs (use these when calling `mcp__linear__save_issue` or related tools):
- Team ID: `2de84a9b-453b-4991-8e09-f88715fa926e`
- Project ID: `c3afdc26-d306-4f72-bdb3-de9b01060d0f`

---

## Setup (do this first, every time)

1. Read `CLAUDE.local.md` for local binary paths and environment settings. Use the Flutter binary path from there for every Flutter command — `flutter` is not on the default shell PATH.
2. Read `CLAUDE.md` and `docs/ARCHITECTURE.md` to orient yourself before touching any code.

---

## Workflow

### 1. Fetch the plan

Retrieve the issue details and find the implementation plan comment left by the `plan` skill:

Call `mcp__linear__get_issue`, then `mcp__linear__list_comments` on the issue.

**If no approved plan comment exists — stop.** Report back:

> "No approved plan found on HAB-XX. Invoke the `plan` skill to produce and approve a plan before implementation can begin."

### 2. Move issue to In Progress

Call `mcp__linear__save_issue` with `state: "In Progress"`.

### 3. Create or switch to the feature branch

Branch naming: `feature/HAB-XX-<short-description>` (2–4 words, kebab-case).

- If already on the correct branch, continue.
- Otherwise: `git checkout -b feature/HAB-XX-<short-description>`

### 4. TDD cycle

**Red — write failing tests first.**

- Mirror the source path under `test/`: `lib/slices/foo/domain/bar.dart` → `test/slices/foo/domain/bar_test.dart`.
- Tests must fail before you write any implementation. Run `<flutter binary> test <test-file>` (using the path from `CLAUDE.local.md`) to confirm failure.
- Do not write implementation code until tests are red.

**Green — implement the minimum code to pass.**

- Write only what is needed to make the failing tests pass. Follow `docs/ARCHITECTURE.md` for structure and `CLAUDE.md` for code style.
- Follow the vertical-slice structure:
  - Domain (`domain/`) — models, interfaces, pure business logic. No Flutter, no sqflite imports.
  - Data (`data/`) — repository implementations. Imports sqflite; depends on domain interfaces only.
  - UI generic (`ui/generic/`) — Riverpod notifiers and shared state. No platform widgets.
  - UI platform (`ui/ios/`, `ui/android/`) — Cupertino and Material widgets respectively.
- Never import across feature boundaries except through shared Riverpod providers.
- Follow the [Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md).

**Refactor — clean up without breaking tests.**

Remove duplication, improve naming, simplify logic. Re-run `<flutter binary> test` after every refactor step.

### 5. Schema / data migrations

If your implementation adds, removes, or renames tables or columns, changes column types, or adds/drops indexes, write a migration before committing:

1. Bump `HabitLoopDatabase` `version` by 1 (e.g. `version: 1` → `version: 2`).
2. Add an `onUpgrade` handler in `HabitLoopDatabase` that applies the DDL changes for each version step.
3. Write a migration test in `test/infrastructure/persistence/habit_loop_database_test.dart`:
   - Open a database at the previous schema version (recreate the old DDL manually).
   - Re-open with the new version so `onUpgrade` runs.
   - Assert the new tables/columns exist and existing data is preserved.
4. Never apply destructive DDL (e.g. `DROP COLUMN`) without an explicit user decision — stop and ask first.

**What does NOT require a migration:** connection-level pragmas (`journal_mode`, `foreign_keys`, `synchronous`), changes to Dart model fields that already have a nullable or default column, and in-memory-only changes (Riverpod state, caches).

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

- **`docs/ARCHITECTURE.md`** affected → ask orchestrator to invoke the `plan` skill to update it.
- **`docs/PRODUCT_SPEC.md`** affected → ask the orchestrator to update it directly (it is a markdown file in the repo, not owned by any specific skill) and wait for confirmation.

Both can be requested simultaneously. Only proceed after the orchestrator confirms those updates are committed.

Never update `docs/BACKLOG.md` or `docs/CHANGELOG.md` — those are owned by the `ship` skill.

**PII constraint:** never pass user-entered text (habit names, notes, stop reasons) to `CrashlyticsService` — only field lengths, IDs, counts, and enum values. Local `logLocal()` calls may include more detail since logs never leave the device.

### 9. Format

Apply `dart format` in a **separate, formatting-only commit before the functional commit**:

```bash
dart format -l 120 lib/ test/
```

If any files changed, stage only those files and commit with a `style:` prefix:

```bash
git commit -m "style: apply dart format (HAB-XX)"
```

If no files changed, skip this step. Never mix formatting changes with functional changes in the same commit — keeping them separate makes the PR diff reviewable and ensures CI's `dart format -l 120 --set-exit-if-changed` check always passes.

### 10. Commit

Stage only the files you changed (never `git add -A` or `git add .`):

```bash
git commit -m "$(cat <<'EOF'
<type>: <short summary>

<optional body explaining why this change was needed>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.

### 11. Push

```bash
git push -u origin <branch-name>
```

### 12. Open a PR

```bash
gh pr create \
  --title "<type>: <summary>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet points>

## Linear
Closes HAB-XX

## Test plan
- [ ] <what was tested>
- [ ] flutter test passes
- [ ] flutter analyze passes
- [ ] Smoke tested

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

### 13. Move issue to In Review

Call `mcp__linear__save_issue` with `state: "In Review"`.

### 14. Post the PR link to the issue

Call `mcp__linear__save_comment` on the issue with the PR URL:

```
PR opened: <PR URL>
```

### 15. Request reviews

Report back to the orchestrator:

> "PR #<N> is open at <url>. Please invoke `review` and `audit` simultaneously."

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
