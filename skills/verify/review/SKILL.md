---
name: review
effort: FOCUSED
reasoning: ARCHITECTURAL
output_style: CONCISE
description: Architectural review of a PR. Checks for layer violations, dependency direction, module boundary breaches, naming/placement issues, and interface drift. Leaves inline comments prefixed with [review] and produces a structured summary. Invoke after `implement` opens a PR, before human review, in parallel with `audit`.
---

The Git host is **GitHub**. The issue identifier prefix is **HAB**.

This skill produces reviews, not code.

---

## Steps

### 1. Resolve the repository and PR details

```bash
git remote get-url origin   # extract {owner}/{repo}
gh pr view <number> --json headRefOid,files
```

### 2. Fetch the full diff

```bash
gh pr diff <number>
```

### 3. Read changed source files

Read the full source of every changed file that is relevant to the architecture. Do not rely on the diff alone.

### 4. Check for architectural concerns

Evaluate each changed file against:

@skills/verify/review/resources/architectural-checks.md

Before flagging a finding, verify:
- Is the scenario already handled by a path not visible in the diff?
- Does an existing test cover this case?

Only report findings you can fully characterise.

### 5. Leave inline comments

For each finding tied to a specific file and line, post an inline comment. Prefix every comment body with `**[review]**`.

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  --method POST \
  --field body="**[review]** <comment>" \
  --field commit_id="<head sha>" \
  --field path="<file>" \
  --field line=<line> \
  --field side="RIGHT"
```

For findings that span multiple files, post a general PR comment:

```bash
gh pr comment <number> --body "**[review]** <comment>"
```

Post one comment per distinct finding. Do not batch unrelated issues.

### 6. Produce a structured summary

After posting all comments:

```
### Architectural review — PR #<N>

#### 🔴 Must fix before merge
<finding: layer or boundary violation that would compound over time>

#### 🟡 Should fix
<finding: inconsistency or naming drift that makes the codebase harder to navigate>

#### ✅ Architecture looks good
<brief note on what was done correctly>
```

Omit a section if empty. Do not flag style issues.
