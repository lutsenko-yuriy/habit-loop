---
name: ship
effort: RAPID
reasoning: TACTICAL
tools: linear,github,files
output_style: CONCISE
description: Post-merge housekeeping after a PR is approved. Moves the linked Linear issues to "In QA", adds a CHANGELOG entry, regenerates BACKLOG.md, bumps pubspec.yaml version, proposes PRODUCT_SPEC.md and GLOSSARY.md updates for approval, commits everything onto the feature branch, pushes, and merges. Invoke when the user approves a PR, before merging. The ticket stays In QA until the user manually moves it to Done after QA sign-off.
---

@skills/shared/project-config.md

Use the **Team ID** and **Project ID** from the project config when calling `mcp__linear__save_issue` or related tools.

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

Determine the target state by inspecting the PR file list (`gh pr view <number> --json files`), using the **In QA path patterns** from the project config.

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

@skills/manage/ship/resources/changelog-tags.md

### 3. Regenerate BACKLOG.md

Open `docs/BACKLOG.md` and remove the completed ticket(s) from the remaining-work list for their milestone. If all issues in the milestone are Done, note the milestone as complete.

Do not rewrite the rest of the file.

### 4. Bump the version

Open the version file (from the project config) and update the version name (`X.Y.Z` part) to match the new `[X.Y.Z]` entry added in step 2.

Do not touch the build number — CI manages it automatically (see version management in project config).

### 5. Update PRODUCT_SPEC.md and GLOSSARY.md

Skip this step if the new CHANGELOG entry (added in step 2) contains only `[meta]`, `[ci]`, or `[app]` tags — those PRs introduce no observable user-facing behaviour change. For all other PRs (`[user]` entries), proceed as follows:

1. Fetch the PR diff: `gh pr diff <number>`
2. Re-read the ticket description (already fetched in step 1).
3. Determine what changed or was added (file paths from the project config):
   - **Product spec** — identify any new or modified user-facing behaviour. Propose a minimal, precise addition or edit to the relevant section (append a new bullet or update an existing one; never rewrite unrelated content).
   - **Glossary** — identify any new canonical domain terms introduced by the feature. For each, propose a new row in the appropriate table with a definition and code symbol.
4. Present the proposed changes to the user **before writing anything**. Show the exact text to be added or replaced (diff-style if helpful). Wait for explicit approval or revision instructions.
5. Apply only the approved changes.

If no changes are needed for a file, skip it. If the user declines all changes, skip to step 6.

### 6. Commit, push, and merge

Stage the files changed above and commit onto the feature branch. Include the product spec and glossary (paths from the project config) only if they were modified in step 5:

```bash
git add <changelog> <backlog> <version-file>   # paths from project config
# add only if modified:
git add <product-spec> <glossary>              # paths from project config
git commit -m "chore: release HAB-XX, bump version to X.Y.Z"
git push
```

Then merge the PR:

```bash
gh pr merge <number> --squash --delete-branch
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

### 7. Report back

Confirm: issue(s) moved to In QA (or Done), changelog updated, version bumped, docs updated (list which files changed), PR merged. Include the new version number and the PR URL. Remind the user to move the ticket to Done in Linear once QA has passed.

After reporting, propose: *"Want to run `/debrief HAB-XX` to capture what you learned from this ticket?"* (optional — do not block on it)
