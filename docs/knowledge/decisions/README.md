# Architecture Decision Records

Standing decisions — not experiments, not ticket retrospectives — tracked here. One file per decision under this directory. Mirrors the `docs/experiments/` registry pattern.

## When to write an ADR

Write one when a ticket's research or implementation concludes in a decision that should be discoverable **without knowing which ticket produced it** — e.g. "we chose MIT licence," "we chose this docs structure." Day-to-day research notes and ticket retrospectives stay in `docs/knowledge/notes/HAB-XX.md`; an ADR is the short, dated, standalone record of the *decision itself*, linking back to the ticket note for full rationale.

## Starting an ADR

1. Pick the next sequential `ADR-NNNN` ID from the index table below (4-digit, zero-padded, e.g. `ADR-0001` — the ticket count alone is already in the hundreds, so 3 digits won't last).
2. Copy `docs/knowledge/decisions/TEMPLATE.md` to `docs/knowledge/decisions/ADR-NNNN-<short-name>.md`, where `<short-name>` is a kebab-case slug (mirrors branch naming, e.g. `feature/HAB-XX-<short-description>`).
3. Replace the template's H1 with a one-sentence description of the decision, commit-message style (e.g. "add per-channel distribute toggles to manual dispatch") — not just a noun-phrase title.
4. Fill in Context, Decision, Alternatives considered, Related ticket, and Date.
5. Add a row to the Index table, using the same one-sentence description in the Description column.

## ID format

`ADR-NNNN` — 4-digit, zero-padded, sequential. Deliberately wider than `docs/experiments/`'s 3-digit `EXP-NNN`: this project is already past ticket #170 four months in, and ADRs should never need a format change to keep up.

## Statuses

| Status | Meaning |
|---|---|
| `proposed` | Drafted, not yet acted on |
| `accepted` | In effect |
| `rejected` | Considered, not adopted |
| `superseded` | Replaced by a later ADR — link the replacement |

## Index

| ID | Description | Status | Date | Related ticket |
|---|---|---|---|---|
| ADR-0001 | adopt the MIT licence for the repository | `accepted` | 2026-07-04 | HAB-109 |
| ADR-0002 | review showup-redemption requests manually until load becomes unbearable | `accepted` | 2026-07-04 | HAB-140 |
