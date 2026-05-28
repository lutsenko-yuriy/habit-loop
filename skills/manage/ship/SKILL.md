---
name: ship
effort: RAPID
reasoning: TACTICAL
output_style: CONCISE
description: Post-merge housekeeping after a PR is approved. Moves the linked Linear issues to "In QA", adds a CHANGELOG entry, regenerates BACKLOG.md, bumps pubspec.yaml version, commits everything onto the feature branch, pushes, and merges. Invoke when the user approves a PR, before merging. The ticket stays In QA until the user manually moves it to Done after QA sign-off.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

Linear workspace IDs (use these when calling `mcp__linear__save_issue` or related tools):
- Team ID: `2de84a9b-453b-4991-8e09-f88715fa926e`
- Project ID: `c3afdc26-d306-4f72-bdb3-de9b01060d0f`

---

## Steps

Run all steps in order. Each step must succeed before moving to the next.

### 1. Move the linked issue(s) to the correct post-merge state

**Precondition — multi-WU check:** Fetch the issue description (`mcp__linear__get_issue`). If it contains a **Work Units** section with any items still marked ⏳ (not started) or 🔄 (in progress), skip the state determination below and instead:
1. Call `mcp__linear__save_issue` with `state: "In Progress"`.
2. Add a Linear comment: "WU[N] shipped (PR #…). Remaining: [list pending WU bullets]."
3. Proceed to step 2 (CHANGELOG).

Only continue to the state determination when all WUs are ✅.

---

Determine the target state by inspecting the PR file list (`gh pr view <number> --json files`):

**→ In QA** if the PR touches any of:
- `lib/slices/*/ui/` — any widget or screen
- `lib/infrastructure/persistence/` — schema or mapper changes
- `lib/infrastructure/sync/` — Firestore or circuit-breaker behaviour
- `lib/infrastructure/notifications/` — notification scheduling
- `main.dart` — app wiring or startup sequence
- `integration_test/` — **always In QA if integration tests were added or changed**

**→ Done directly** if the PR touches only: pure domain/application logic, documentation, CI config, l10n strings without new screens, or pure refactors where `flutter test` fully owns correctness.

When in doubt, use **In QA**.

Call `mcp__linear__save_issue` with the chosen `state` for each issue linked to the PR. If moving to In QA, do **not** move to Done — the ticket stays there until human testers sign off; the user moves it to Done manually.

### 2. Add a CHANGELOG entry

Open `docs/CHANGELOG.md` and prepend a new entry at the top:

```markdown
## [X.Y.Z] — YYYY-MM-DD (PR #N merged)

### Added / Changed / Fixed

- [user] <user-facing description — what the user sees or gains>
- HAB-XX: <technical detail for developers>
```

Follow semantic versioning (`docs/VERSIONING.md`): patch for bug fixes, minor for new features, major for breaking changes.

**Release note tagging — required for every entry:**

Each CHANGELOG entry MUST include exactly one of the following markers so `scripts/generate_release_notes.py` produces clean user-facing release notes for Firebase App Distribution:

| Marker | When to use | What it does |
|---|---|---|
| `- [user] <description>` | User-visible change | Only `[user]`-tagged lines appear in release notes (tag stripped); all other bullets skipped |
| `- [user-none]` | **No** user-visible changes (CI fixes, refactors, tooling) | Entire entry silently omitted from release notes |
| `- [non-user] <detail>` | Developer-only detail within a tagged entry | Explicit marker for clarity; never appears in release notes |

Rules:
- **CI enforces this** (`scripts/lint_changelog.py` runs on every PR) — entries without `[user]` or `[user-none]` fail the build.
- Add `[user]` lines **before** technical detail lines in the same section.
- `[user]` descriptions must be plain English a non-technical user can understand — no class names, file paths, or jargon.
- Use `[user-none]` (as a single sentinel line) for PRs touching only tests, CI config, docs, internal refactors, or analytics instrumentation with no UI change; mark the remaining bullets `[non-user]`.
- Entries without any marker no longer fall back to dumping all bullets — they are silently skipped (same as `[user-none]`).

### 3. Regenerate BACKLOG.md

Open `docs/BACKLOG.md` and remove the completed ticket(s) from the remaining-work list for their milestone. If all issues in the milestone are Done, note the milestone as complete.

Do not rewrite the rest of the file.

### 4. Bump the version

Open `pubspec.yaml` and update the version name (`X.Y.Z` part of the `version:` field) to match the new `[X.Y.Z]` entry added in step 2.

Do not touch the build number (`+N` part) — CI manages it automatically.

### 5. Commit, push, and merge

Stage only the files changed above and commit onto the feature branch:

```bash
git add docs/CHANGELOG.md docs/BACKLOG.md pubspec.yaml
git commit -m "chore: release HAB-XX, bump version to X.Y.Z"
git push
```

Then merge the PR:

```bash
gh pr merge <number> --squash --delete-branch
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

### 6. Report back

Confirm: issue(s) moved to In QA, changelog updated, version bumped, PR merged. Include the new version number and the PR URL. Remind the user to move the ticket to Done in Linear once QA has passed.
