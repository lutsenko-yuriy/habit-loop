# Project Knowledge Base

A local Markdown vault for ticket-scoped research, learnings, retrospectives, and standing decisions — committed to the repo so Claude and the user share the same history across sessions.

**Standing decisions** that should be discoverable without knowing which ticket produced them (e.g. "we chose MIT licence") live in `decisions/` (ADRs) — see `docs/knowledge/decisions/README.md`. Day-to-day, ticket-scoped research stays in `notes/`; an ADR links back to the relevant `HAB-XX.md` file for full rationale.

## Structure

```
docs/knowledge/
├── README.md          # this file
├── notes/
│   └── HAB-XX.md      # one file per ticket; created on first /note or /debrief use
├── decisions/
│   └── ADR-NNN-<short-name>.md   # one file per standing decision; see decisions/README.md
└── checkups/
    ├── README.md          # ledger: per-tier cadence/due table + open/resolved findings tables
    ├── TEMPLATE.md         # per-run write-up skeleton
    └── CHK-YYYY-MM-DD-<tier>.md   # one dated write-up per checkup run; written by /checkup
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
| `/checkup [light\|heavy\|status]` | Writes a dated `checkups/CHK-YYYY-MM-DD-<tier>.md` and updates `checkups/LEDGER.md` |

On first use for a ticket, the file is created from `docs/knowledge/notes/TEMPLATE.md`.

## How to query

- All notes for a ticket: `grep -r "HAB-XX" docs/knowledge/notes/`
- Recent decisions: open `docs/knowledge/notes/HAB-XX.md` directly
- Claude reads the relevant file at the start of `/debrief` and can be asked to read any file on demand

## Agent memory constraints

Ticket state (Backlog, In Progress, In Review, In QA, Done) is **never stored in agent memory** — memory entries go stale within hours and cause incorrect answers about what is currently in flight. **Always query Linear directly** for current ticket state.

General rule: only store in memory what Linear, git, and the codebase cannot answer. State that a tool can look up authoritatively should never be duplicated in memory.
