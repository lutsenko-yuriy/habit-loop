---
name: debrief
effort: FOCUSED
reasoning: ARCHITECTURAL
needs_session_tools: true
output_style: CONCISE
description: Post-ticket retrospective. Reads git history, conducts a one-question-at-a-time dialog, proposes targeted improvements to workflow/skill/docs files, applies approved changes, and writes a summary to the project knowledge base.
---

The issue identifier prefix is **HAB**.

This skill produces workflow improvements and a retrospective record, not code.

---

## Steps

### 1. Load context

- `git log --oneline -20` to see the recent commit history
- Read `docs/FEATURE_WORKFLOW.md` and `docs/TROUBLESHOOT_WORKFLOW.md`

### 2. Open the dialog

Ask one open question:

> "Let's debrief HAB-XX. How did it go overall?"

### 3. Iterate — one question at a time

**Spirit of the dialog:** the goal is honest reflection — the user leaves with a clear-eyed picture of what worked and what to change next time.

@skills/shared/dialog-principles.md

Cover these four dimensions (follow the conversation's natural order — do not force a rigid sequence):

| Dimension | What to surface |
|---|---|
| What went well | Practices, decisions, or tools that worked and should be repeated |
| What was hard or surprising | Friction, unexpected complexity, or unclear requirements |
| What slowed things down | Process bottlenecks, back-and-forth, missing context |
| What to change | Concrete things to do differently next time |

If the user says "that's it", "nothing else", or similar, proceed to step 4 even if not all four dimensions were explicitly covered.

### 4. Synthesise findings

Identify actionable improvements from the dialog. For each:

- Name the artifact (`docs/FEATURE_WORKFLOW.md`, `skills/build/implement/SKILL.md`, etc.)
- Show the exact change (diff-style: what line/block is replaced and with what)
- One-sentence rationale tied to what the user said

Group by artifact. Present everything to the user and wait for approval. Do not write any files before approval.

If no actionable improvements emerged, say so explicitly and proceed to step 5.

### 5. Apply approved changes

Write only the approved changes to their respective files. Skip any the user declined.

### 5.1 Commit and open a PR (if changes were applied)

If at least one improvement was approved in step 4:

1. Create a branch from the latest `origin/main`:
   ```bash
   git fetch origin
   git checkout -b feature/HAB-XX-debrief origin/main
   ```
2. Stage and commit the changed files:
   ```bash
   git add <files>
   git commit -m "meta: debrief HAB-XX — <short summary of changes>"
   ```
3. Push and open a PR titled `meta: debrief HAB-XX — <short summary>`.
4. Include the PR URL in the report (step 7).

If no changes were approved, skip this step.

### 6. Write to the knowledge base

Append a dated block to the `## Debrief summary` section of `docs/knowledge/notes/HAB-XX.md`.

**If the file does not exist:** create it with this structure first (use the ticket ID as the title placeholder):

```markdown
# HAB-XX: <ticket title>

## Notes

## Debrief summary
```

**Append** to the end of the `## Debrief summary` section:

```markdown
### YYYY-MM-DD

**What went well**
- …

**What was hard or surprising**
- …

**What to change**
- …
```

Use today's date. Mirror the content from the dialog — do not ask the user for anything at this step.

### 7. Report back

Confirm: knowledge base updated at `docs/knowledge/notes/HAB-XX.md`, list any workflow/skill files changed (or "no file changes").

---

## Constraints

- Never modify app code (`lib/`, `test/`, `integration_test/`).
- Never ask more than one question per turn.
- Do not write file changes before the user approves them in step 4.
