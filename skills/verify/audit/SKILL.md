---
name: audit
effort: THOROUGH
reasoning: TACTICAL
tools: github,files
output_style: CONCISE
description: Runtime and migration review of a PR. Checks for launch-time failures, migration issues, platform-specific risks, state consistency problems, and business logic edge cases. Leaves inline comments prefixed with [audit] and produces a structured summary. Invoke after `implement` opens a PR, in parallel with `review`.
---

The Git host is **GitHub**. The tech stack is **Flutter (Dart), Riverpod, sqflite, Firebase**.

---

## What to look for

@skills/verify/audit/resources/audit-checklist.md

---

## How to review

### 1. Fetch the PR diff and file list

```bash
gh pr diff <number>
gh pr view <number> --json files
```

### 2. Read changed source files

Read the full source of any changed domain, data, or integration files. Do not rely on the diff alone.

### 3. Check configuration files

Look for related changes in `pubspec.yaml`, `Info.plist`, `AndroidManifest.xml`, migration files, `HabitLoopDatabase`, `AppContainer`.

### 4. Cross-reference intent

Read `docs/PRODUCT_SPEC.md` and `CLAUDE.md` to understand the intended behaviour and check against it.

### 5. Reason through each potential finding

Before reporting any finding, answer all four questions:
- What is the **exact sequence of events** that triggers the problem?
- Can the **existing code** handle this case through a path not visible in the diff?
- Is the scenario **already covered by a test**?
- What is the **worst-case outcome** — crash, data loss, silent wrong result?

Only report a finding if you can answer all four. A vague trigger scenario is not actionable — discard it.

---

## Leaving comments

Resolve the repo slug: `git remote get-url origin`.

For every finding tied to a specific file and line, post an **inline comment**. Prefix every comment body with `**[audit]**`.

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  --method POST \
  --field body="**[audit]** <comment>" \
  --field commit_id="<head sha>" \
  --field path="<file>" \
  --field line=<line> \
  --field side="RIGHT"
```

For findings that span multiple files or cannot be tied to a specific line, post a general PR comment:

```bash
gh pr comment <number> --body "**[audit]** <comment>"
```

Post one comment per distinct finding. Do not batch unrelated issues — each comment must be self-contained and actionable.

---

## Output format

After posting all comments, produce a structured summary. Omit a section entirely if there are no findings.

### 🔴 Critical — will likely break in production
Issues that would cause crashes, data loss, or silent failures for real users.

### 🟡 Warning — may break under specific conditions
Issues that require a particular state, OS version, or user action to trigger.

### 🟢 Suggestions — low risk, worth considering
Minor improvements to robustness or defensive coding that are not urgent.

### ✅ Looks good
A brief note on what was done well or poses no migration/launch risk.

Be precise: cite the file name, line range, and the exact scenario. Do not flag style issues or things already covered by existing tests unless the test itself is incorrect.
