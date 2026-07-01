# Project Knowledge Base

A local Markdown vault for decisions, learnings, and retrospectives — committed to the repo so Claude and the user share the same history across sessions.

## Structure

```
docs/knowledge/
├── README.md          # this file
└── notes/
    └── HAB-XX.md      # one file per ticket; created on first /note or /debrief use
```

## Per-ticket file format

See `docs/knowledge/notes/TEMPLATE.md` for the canonical structure. In brief:

- `## Notes` — dated headings (`### YYYY-MM-DD`) with named observations (bold title + paragraph body), appended mid-session
- `## Debrief summary` — a single structured block written by `/debrief` after the ticket closes

**Reopened tickets:** if a ticket's notes file is already finalised, do not edit it. Create a new file with a suffix: `HAB-XX-adjust-1.md`, `HAB-XX-adjust-2.md`, etc. The original file is treated as a closed record.

## How entries are written

| Command | Writes to |
|---|---|
| `/note [HAB-XX:] <text>` | Appends a dated observation to `## Notes` |
| `/debrief HAB-XX` | Appends a dated block to `## Debrief summary` |

On first use for a ticket, the file is created from `docs/knowledge/notes/TEMPLATE.md`.

## How to query

- All notes for a ticket: `grep -r "HAB-XX" docs/knowledge/notes/`
- Recent decisions: open `docs/knowledge/notes/HAB-XX.md` directly
- Claude reads the relevant file at the start of `/debrief` and can be asked to read any file on demand
