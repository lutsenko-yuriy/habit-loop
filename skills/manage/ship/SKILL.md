---
name: ship
effort: RAPID
reasoning: TACTICAL
tools: linear,github,files
output_style: CONCISE
description: Post-merge housekeeping after a PR is approved. Moves the linked issues to "In QA", rebases onto the latest main, adds a CHANGELOG entry, regenerates BACKLOG.md, bumps pubspec.yaml version, proposes PRODUCT_SPEC.md and GLOSSARY.md updates for approval, refreshes the generated notes index, commits everything onto the feature branch, pushes, and merges. Invoke when the user approves a PR, before merging. The ticket stays In QA until the user manually moves it to Done after QA sign-off.
---

@skills/shared/project-config.md

Use the **Team ID** and **Project ID** from the PM tool mapping for all PM operations.

---

## Steps

Run all steps in order. Each step must succeed before moving to the next.

### 1. Move the linked issue(s) to the correct post-merge state

Fetch the issue once (PM mapping: **Fetch issue**) — its state and description together cover both preconditions below, so this single fetch serves both checks.

**Precondition — already-in-QA check:** If the fetched state is already **In QA** or **Done**, leave it as-is — skip the state determination below entirely — and proceed to step 2. This guards against a PR that isn't the ticket's primary implementation work (e.g. a debrief-only PR for a ticket whose real QA status was already set by other means, such as manual real-device testing) silently overwriting a state that's still accurate.

**Precondition — multi-WU check:** If the fetched description contains a **Work Units** section with any items still marked ⏳ (not started) or 🔄 (in progress), skip the state determination below and instead:
1. Move the issue to "In Progress" (PM mapping: **Move issue to state**).
2. Add a PM comment: "WU[N] shipped (PR #…). Remaining: [list pending WU bullets]." (**Post comment on issue**)
3. Proceed to step 2 (rebase), then step 3 (drafting `[user]` bullets), then the CHANGELOG entry in step 4.

Only continue to the state determination when all WUs are ✅ and the issue is not already In QA/Done per the check above.

**Precondition — debrief check:** Check whether `docs/knowledge/notes/HAB-XX.md` exists with at least one dated entry under `## Debrief summary`. If it doesn't, stop before continuing — debrief has not run yet for this ticket. Tell the user, and ask whether to invoke `/debrief HAB-XX` now before shipping, or to proceed without it. Do not ship silently past a missing debrief.

---

Determine the target state by inspecting the PR file list (`gh pr view <number> --json files`), using the **In QA path patterns** from the project config.

When in doubt, use **In QA**.

Move each linked issue to the chosen state (PM mapping: **Move issue to state**). If moving to In QA, do **not** move to Done — the ticket stays there until human testers sign off; the user moves it to Done manually.

### 2. Rebase onto the latest main

**First, commit any pending knowledge-note edits** so the tree is clean before rebasing — `/note` may have created a new note file, or edited an already-committed one, earlier in the session without staging it:

```bash
git status --short docs/knowledge/notes/HAB-XX*.md
```

If anything shows, stage and commit it now — do not defer this to step 9, since an *unstaged edit to an already-committed file* (not just a new untracked file) makes the rebase below refuse to run at all:

```bash
git add docs/knowledge/notes/HAB-XX*.md
git commit -m "docs: capture pending /note updates for HAB-XX"
```

Then rebase:

```bash
git fetch origin && git rebase origin/main
```

**If the rebase reports a conflict:** stop immediately — do not proceed to any further step. Tell the user which files conflicted and wait for guidance (resolve manually and `git rebase --continue`, or `git rebase --abort` to cancel this `ship` attempt). Never leave the branch in a mid-rebase/detached-HEAD state without saying so — the issue was already moved to its post-merge state in step 1, so a silent stall here leaves Linear ahead of the actual repo state.

This is what actually enforces `docs/workflows/FEATURE.md` step 1.5's "rebase before merging" guidance — `ship` is the point that calls `gh pr merge`, so it's the natural place to make the rebase non-optional rather than relying on it being remembered by hand. It must run **before** any of steps 3–8 make edits: `git rebase` refuses to run against an uncommitted tree, so doing this later would require stashing or redoing that work (HAB-223).

**This rebase rewrites the branch's commits whenever `main` has moved** (the only case where it does anything) — the local branch now diverges from `origin/<branch>` by SHA, not just by content. Step 9's push must account for this (see step 9).

### 3. Draft the [user] bullets

**Skip this step if the PR's file list (already fetched in step 1's `gh pr view --json files`, or fetch now if step 1 didn't need it) touches no `lib/` paths** — a PR with no application code cannot have user-facing behaviour, so there is nothing to draft and no reason to pay for a diff fetch or an approval round-trip. Classification tags aren't known yet at this point (step 4 determines those), so this check runs on file paths rather than on `[wip]`/`[meta]`/etc., unlike step 7's equivalent skip.

Otherwise, read `skills/manage/draft-release-notes/SKILL.md` and follow it, passing the PR number already in hand, to produce the entry's `[user]` bullets (possibly zero — still a valid outcome even for a `lib/`-touching PR, e.g. a pure refactor). This runs inline, no model switch needed (both skills are RAPID + TACTICAL). Its output feeds step 4 below; `ship` still owns tag classification and `[Unreleased]`-vs-numbered routing itself.

### 4. Add a CHANGELOG entry

**Release note tagging — required for every entry:**

@skills/manage/ship/resources/changelog-tags.md

`## [Unreleased]` sections are **bounded batches**, not one permanent bucket: at most one is ever "open" (accumulating new entries) at a time, and it always sits immediately before the first `## [...]` heading in the file (there is no other content between the file's intro and that first heading — see `docs/CHANGELOG.md`). Once an app-changing entry ships, its new numbered heading is inserted above the open batch, which becomes permanently "sealed" in place — sandwiched between that new release and whatever came before. A fresh `## [Unreleased]` then opens at the new top the next time a non-app-changing entry needs one. This keeps the file scannable: you never scroll through more than one batch's worth of internal-only entries to find the latest release.

Determine this entry's classification tags first (per the table above), then route it:

**If the entry contains at least one `[user]` and/or `[app]` tag** (an app-changing entry — this is what triggers step 6's version bump below): insert a fresh numbered heading immediately before the file's current first `## [...]` heading (before anything else — including an open `## [Unreleased]` batch, which this seals in place below the new heading). **If the file has no `## [...]` heading at all yet** (a from-scratch CHANGELOG), insert it right after the file's intro paragraph instead:

```markdown
## [X.Y.Z] — YYYY-MM-DD (PR #N merged)

### Added / Changed / Fixed

- [user] <user-facing description — what the user sees or gains>
- HAB-XX: <technical detail for developers>
```

If step 3 returned zero `[user]` bullets (a valid outcome — e.g. a pure refactor with no observable behaviour change), omit the `- [user]` line entirely rather than inventing one; the entry is `[app]`-only:

```markdown
## [X.Y.Z] — YYYY-MM-DD (PR #N merged)

### Added / Changed / Fixed

- [app] HAB-XX: <technical detail for developers>
```

Follow semantic versioning (`docs/VERSIONING.md`): patch for bug fixes, minor for new features, major for breaking changes.

**Otherwise** (entry classified only as `[ci]`/`[meta]`/`[test]`/`[wip]`/`[user-none]`/`[trivial]` — nothing here changed the app, or `[trivial]` and no explicit immediate release was requested): look at the file's current first `## [...]` heading:

- **If it's `## [Unreleased]`** (a batch is already open): append the bullet to the top of its existing bullet list, right after its explanatory blurb paragraph — do not create a new heading.
- **If it's a numbered `## [X.Y.Z]` heading instead, or there's no heading at all yet** (no batch is currently open): insert a **brand-new** `## [Unreleased]` section immediately before that numbered heading (or right after the file's intro paragraph, if there was no heading at all), with this bullet as its first entry:

```markdown
## [Unreleased]

Internal-only changes (CI, tooling, tests, workflow/skill docs) that did not change the app — no `pubspec.yaml` version bump, no build, no release. See `docs/VERSIONING.md` for the rule.

- [ci] (PR #N) HAB-XX: <technical detail for developers>
```

Once a `## [Unreleased]` batch is sealed by a later release (see the app-changing branch above), its bullets stay exactly where they are permanently — never move them, and never append further bullets to a sealed batch. Only the single batch currently at position 0 (if any) is ever appended to.

### 5. Regenerate BACKLOG.md

Open `docs/BACKLOG.md` and remove the completed ticket(s) from the remaining-work list for their milestone. If all issues in the milestone are Done, note the milestone as complete.

Do not rewrite the rest of the file.

### 6. Bump the version

**Only if step 4 created a new numbered heading** (the entry had a `[user]`/`[app]` tag): open the version file (from the project config) and update the version name (`X.Y.Z` part) to match the new `[X.Y.Z]` entry added in step 4.

**If step 4 instead appended to `## [Unreleased]`:** skip this step entirely — do not touch the version file. `pubspec.yaml`'s version represents the app's build version, not the repo's commit history (`docs/VERSIONING.md`); it only changes when the app itself changes.

Do not touch the build number — CI manages it automatically via `version-*` git tags, not a `pubspec.yaml` commit (HAB-241; see version management in project config).

### 7. Update PRODUCT_SPEC.md and GLOSSARY.md

Skip this step if the new CHANGELOG entry (added in step 4) contains only `[meta]`, `[ci]`, `[app]`, or `[wip]` tags — those PRs introduce no observable user-facing behaviour change. For all other PRs (`[user]` entries), proceed as follows:

1. Fetch the PR diff: `gh pr diff <number>` — reuse step 3's fetch if it already ran and no commits landed since (e.g. no review-loop pushes in between); otherwise fetch fresh, since a stale diff here would miss review-driven changes.
2. Re-read the ticket description (already fetched in step 1).
3. Determine what changed or was added (file paths from the project config):
   - **Product spec** — identify any new or modified user-facing behaviour. Propose a minimal, precise addition or edit to the relevant section (append a new bullet or update an existing one; never rewrite unrelated content).
   - **Glossary** — identify any new canonical domain terms introduced by the feature. For each, propose a new row in the appropriate table with a definition and code symbol.
4. Present the proposed changes to the user **before writing anything**. Show the exact text to be added or replaced (diff-style if helpful). Wait for explicit approval or revision instructions.
5. Apply only the approved changes.

If no changes are needed for a file, skip it. If the user declines all changes, skip to step 8.

### 8. Refresh the generated notes index

Regenerate `docs/knowledge/notes/INDEX.md` so it reflects the actual note corpus after step 2's rebase and any notes touched by this ticket — not whatever shape it had before either. This closes a merge-race window: two branches independently bumping the same bookmark's summary count merge cleanly with no textual conflict, but the merged count is wrong unless someone regenerates after the merge (HAB-223).

```bash
python3 scripts/notes/index.py
python3 scripts/notes/index.py --check
```

The second call is a validation gate, not a staleness check — the regeneration above already fixed staleness, so `--check` here can only fail on a genuine authoring error (missing `bookmarks:` key, unknown bookmark, malformed frontmatter). `main` has no branch protection, so nothing else blocks a bad index from landing once step 9 pushes and merges — CI's own `--check` run never gates the merge. **If `--check` fails, stop and tell the user; do not commit an invalid index.**

If `docs/knowledge/notes/INDEX.md` changed, include it in step 9's commit.

### 9. Commit, push, and merge

Stage the files changed above and commit onto the feature branch. Include the product spec and glossary (paths from the project config) only if they were modified in step 7. (Any `/note`-created or -edited file for this ticket is already committed by step 2 — nothing further to catch here.)

```bash
git add <changelog> <backlog>                  # paths from project config
# add only if step 6 actually bumped it:
git add <version-file>                         # paths from project config
# add only if modified:
git add <product-spec> <glossary>              # paths from project config
# add only if step 8 regenerated it:
git add docs/knowledge/notes/INDEX.md
```

Commit with **exactly one** of these two messages — whichever matches what step 6 actually did — then push:

- Step 6 bumped the version: `git commit -m "chore: release HAB-XX, bump version to X.Y.Z"`
- Step 6 was skipped (entry went to `## [Unreleased]`): `git commit -m "chore: release HAB-XX (internal-only, no version bump)"`

```bash
git push --force-with-lease
```

**Use `--force-with-lease`, not a bare `git push`.** Step 2's rebase rewrites this branch's commit SHAs whenever `origin/main` had moved since the branch was last pushed — which is exactly the case the rebase exists to handle. A bare `git push` is rejected non-fast-forward in that case, so `ship` would halt post-merge-decision (issue already moved, all edits already committed locally) with nothing actually merged. `--force-with-lease` (not plain `--force`) still refuses if someone else pushed to this branch in the meantime, so it doesn't blindly clobber concurrent work.

Then merge the PR:

```bash
gh pr merge <number> --squash --delete-branch
```

Use `/opt/homebrew/bin/gh` if `gh` is not on the PATH.

### 10. Report back

Confirm: issue(s) moved to In QA (or Done), changelog updated (state whether it landed under a new `[X.Y.Z]` heading or `## [Unreleased]`), version bumped or explicitly left untouched, docs updated (list which files changed), PR merged. Include the new version number (if bumped) and the PR URL. Remind the user to move the ticket to Done in the PM tool once QA has passed.
