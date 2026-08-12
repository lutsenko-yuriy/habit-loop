---
name: note
effort: RAPID
reasoning: MECHANICAL
output_style: CONCISE
description: Capture a quick observation or decision into the project knowledge base mid-session. Infers the active ticket from session context (confirms before writing), appends a timestamped bullet to docs/knowledge/notes/HAB-XX.md, and creates the file if it does not yet exist.
---

@skills/shared/project-config.md

The knowledge base path and per-ticket file naming are in the project config above.

This skill writes one entry, then stops. It does not open a dialog.

---

## Steps

### 1. Resolve the ticket tag

**If the argument starts with `HAB-XX:` (explicit tag):** use that ticket ID. Strip the `HAB-XX:` prefix to get the note text.

**If no explicit tag:** check the current session context for an active ticket (e.g. a ticket currently In Progress, or one mentioned in the recent conversation).

- If a ticket is found: ask once — *"This note will be tagged to HAB-XX — correct?"* Wait for confirmation before writing.
  - If the user confirms: proceed with that ticket.
  - If the user corrects it (supplies a different ticket or label): use the corrected value.
- If no ticket is found: ask the user — *"Which ticket should this note be tagged to?"* Use the answer; do not guess.

One question maximum. Do not write until the ticket is resolved.

### 2. Resolve the note text

The note text is everything after the `HAB-XX:` prefix in the argument, or the full argument if no explicit tag was given.

If the argument is empty after stripping the tag (or no argument was given at all): ask — *"What's the note?"* — and use the answer.

### 3. Write the entry

Resolve the target file: `docs/knowledge/notes/HAB-XX.md` (using the ticket ID from step 1).

**If the file does not exist:** create it from `docs/knowledge/notes/TEMPLATE.md` — substitute the ticket ID and title, then clear the placeholder content in `## Notes` and `## Debrief summary`.

**If the file already has a `## Debrief summary` with content** (i.e. the ticket was previously finalised): do not edit it. Create `docs/knowledge/notes/HAB-XX-adjust-N.md` instead, where N is the next available suffix (1, 2, …). Use the same template structure.

**Append** a dated heading and named observation at the end of the `## Notes` section:

```markdown
### YYYY-MM-DD

**<derived title from note text>**

<note text>
```

Use today's date in `YYYY-MM-DD` format.

**Set the `bookmarks:` frontmatter key.** Read `docs/knowledge/notes/BOOKMARKS.md` and pick the 1–3 existing bookmarks that best match the note text. If nothing in the vocabulary fits, use `bookmarks: []` — do not invent a new bookmark here (that stays a `/debrief`-time or `/checkup heavy`-time decision, since both have room for a multi-question dialog and `/note`'s one-question budget above does not). Format: an inline list at the very top of the file, e.g. `bookmarks: [ci-flakiness, scope-creep]` (block-list `- item` style is rejected by `index.py --check`). Merge into any existing `bookmarks:` key rather than overwriting it. Then run `python3 scripts/notes/index.py` to regenerate `INDEX.md`.

### 4. Report back

One line: *"Noted in `docs/knowledge/notes/HAB-XX.md`."*

---

## Constraints

- Never write to `## Debrief summary` — that section belongs to `/debrief`.
- One question maximum across all steps. If both the ticket and the note text are unknown, ask for the ticket first; ask for the note text in the same response only if the ticket was explicit in the argument.
- Never modify app code, tests, or any file outside `docs/knowledge/notes/`.
- Never propose a new bookmark from `/note` — pick only from `docs/knowledge/notes/BOOKMARKS.md`'s existing vocabulary, or use `bookmarks: []`.
