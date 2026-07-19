---
name: ship
effort: RAPID
reasoning: TACTICAL
tools: linear,github,files
output_style: CONCISE
description: Post-merge housekeeping after a PR is approved. Moves the linked issues to "In QA", adds a CHANGELOG entry, regenerates BACKLOG.md, bumps pubspec.yaml version, proposes PRODUCT_SPEC.md and GLOSSARY.md updates for approval, commits everything onto the feature branch, pushes, and merges. Invoke when the user approves a PR, before merging. The ticket stays In QA until the user manually moves it to Done after QA sign-off.
---

@skills/shared/project-config.md

Use the **Team ID** and **Project ID** from the PM tool mapping for all PM operations.

---

## Steps

Run all steps in order. Each step must succeed before moving to the next.

### 1. Move the linked issue(s) to the correct post-merge state

**Precondition — already-in-QA check:** Fetch the issue's current state (PM mapping: **Fetch issue**). If it is already **In QA** or **Done**, leave it as-is — skip the state determination below entirely — and proceed to step 2. This guards against a PR that isn't the ticket's primary implementation work (e.g. a debrief-only PR for a ticket whose real QA status was already set by other means, such as manual real-device testing) silently overwriting a state that's still accurate.

**Precondition — multi-WU check:** Fetch the issue description (PM mapping: **Fetch issue**). If it contains a **Work Units** section with any items still marked ⏳ (not started) or 🔄 (in progress), skip the state determination below and instead:
1. Move the issue to "In Progress" (PM mapping: **Move issue to state**).
2. Add a PM comment: "WU[N] shipped (PR #…). Remaining: [list pending WU bullets]." (**Post comment on issue**)
3. Proceed to step 2 (CHANGELOG).

Only continue to the state determination when all WUs are ✅ and the issue is not already In QA/Done per the check above.

---

Determine the target state by inspecting the PR file list (`gh pr view <number> --json files`), using the **In QA path patterns** from the project config.

When in doubt, use **In QA**.

Move each linked issue to the chosen state (PM mapping: **Move issue to state**). If moving to In QA, do **not** move to Done — the ticket stays there until human testers sign off; the user moves it to Done manually.

### 2. Add a CHANGELOG entry

**Release note tagging — required for every entry:**

@skills/manage/ship/resources/changelog-tags.md

`## [Unreleased]` sections are **bounded batches**, not one permanent bucket: at most one is ever "open" (accumulating new entries) at a time, and it always sits at the absolute top of the file. Once an app-changing entry ships, its new numbered heading is inserted above the open batch, which becomes permanently "sealed" in place — sandwiched between that new release and whatever came before. A fresh `## [Unreleased]` then opens at the new top the next time a non-app-changing entry needs one. This keeps the file scannable: you never scroll through more than one batch's worth of internal-only entries to find the latest release.

Determine this entry's classification tags first (per the table above), then route it:

**If the entry contains at least one `[user]` and/or `[app]` tag** (an app-changing entry — this is what triggers step 4's version bump below): insert a fresh numbered heading at the **absolute top of the file** (position 0, before anything else — including an open `## [Unreleased]` batch, which this seals in place below the new heading):

```markdown
## [X.Y.Z] — YYYY-MM-DD (PR #N merged)

### Added / Changed / Fixed

- [user] <user-facing description — what the user sees or gains>
- HAB-XX: <technical detail for developers>
```

Follow semantic versioning (`docs/VERSIONING.md`): patch for bug fixes, minor for new features, major for breaking changes.

**Otherwise** (entry classified only as `[ci]`/`[meta]`/`[test]`/`[wip]`/`[user-none]` — nothing here changed the app): look at what currently sits at the absolute top of the file (position 0):

- **If it's already `## [Unreleased]`** (a batch is already open): append the bullet to the top of its existing bullet list, right after its explanatory blurb paragraph — do not create a new heading.
- **If it's a numbered `## [X.Y.Z]` heading instead** (no batch is currently open — the last thing shipped was a release): insert a **brand-new** `## [Unreleased]` section at the absolute top of the file, above that numbered heading, with this bullet as its first entry:

```markdown
## [Unreleased]

Internal-only changes (CI, tooling, tests, workflow/skill docs) that did not change the app — no `pubspec.yaml` version bump, no build, no release. See `docs/VERSIONING.md` for the rule.

- [ci] (PR #N) HAB-XX: <technical detail for developers>
```

Once a `## [Unreleased]` batch is sealed by a later release (see the app-changing branch above), its bullets stay exactly where they are permanently — never move them, and never append further bullets to a sealed batch. Only the single batch currently at position 0 (if any) is ever appended to.

### 3. Regenerate BACKLOG.md

Open `docs/BACKLOG.md` and remove the completed ticket(s) from the remaining-work list for their milestone. If all issues in the milestone are Done, note the milestone as complete.

Do not rewrite the rest of the file.

### 4. Bump the version

**Only if step 2 created a new numbered heading** (the entry had a `[user]`/`[app]` tag): open the version file (from the project config) and update the version name (`X.Y.Z` part) to match the new `[X.Y.Z]` entry added in step 2.

**If step 2 instead appended to `## [Unreleased]`:** skip this step entirely — do not touch the version file. `pubspec.yaml`'s version represents the app's build version, not the repo's commit history (`docs/VERSIONING.md`); it only changes when the app itself changes.

Do not touch the build number — CI manages it automatically (see version management in project config).

### 5. Update PRODUCT_SPEC.md and GLOSSARY.md

Skip this step if the new CHANGELOG entry (added in step 2) contains only `[meta]`, `[ci]`, `[app]`, or `[wip]` tags — those PRs introduce no observable user-facing behaviour change. For all other PRs (`[user]` entries), proceed as follows:

1. Fetch the PR diff: `gh pr diff <number>`
2. Re-read the ticket description (already fetched in step 1).
3. Determine what changed or was added (file paths from the project config):
   - **Product spec** — identify any new or modified user-facing behaviour. Propose a minimal, precise addition or edit to the relevant section (append a new bullet or update an existing one; never rewrite unrelated content).
   - **Glossary** — identify any new canonical domain terms introduced by the feature. For each, propose a new row in the appropriate table with a definition and code symbol.
4. Present the proposed changes to the user **before writing anything**. Show the exact text to be added or replaced (diff-style if helpful). Wait for explicit approval or revision instructions.
5. Apply only the approved changes.

If no changes are needed for a file, skip it. If the user declines all changes, skip to step 6.

### 6. Commit, push, and merge

Stage the files changed above and commit onto the feature branch. Include the product spec and glossary (paths from the project config) only if they were modified in step 5. Also check for an uncommitted knowledge note for this ticket (`git status --short docs/knowledge/notes/HAB-XX*.md`) — `/note` may have written one earlier in the session that never got staged; include it in this commit if found.

```bash
git add <changelog> <backlog>                  # paths from project config
# add only if step 4 actually bumped it:
git add <version-file>                         # paths from project config
# add only if modified:
git add <product-spec> <glossary>              # paths from project config
# add if present and uncommitted:
git add docs/knowledge/notes/HAB-XX*.md        # catches /note output missed earlier in the session
```

Commit with **exactly one** of these two messages — whichever matches what step 4 actually did — then push:

- Step 4 bumped the version: `git commit -m "chore: release HAB-XX, bump version to X.Y.Z"`
- Step 4 was skipped (entry went to `## [Unreleased]`): `git commit -m "chore: release HAB-XX (internal-only, no version bump)"`

```bash
git push
```

Then merge the PR:

```bash
gh pr merge <number> --squash --delete-branch
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

### 7. Report back

Confirm: issue(s) moved to In QA (or Done), changelog updated (state whether it landed under a new `[X.Y.Z]` heading or `## [Unreleased]`), version bumped or explicitly left untouched, docs updated (list which files changed), PR merged. Include the new version number (if bumped) and the PR URL. Remind the user to move the ticket to Done in the PM tool once QA has passed.
