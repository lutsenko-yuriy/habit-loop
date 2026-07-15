# ADR-0002 — review showup-redemption requests manually until load becomes unbearable

## Status
`accepted`

## Context
Showup redemption (writing a note to reclaim an auto-failed showup within the tail zone) needed a support workflow: how are redemption requests submitted, reviewed, and how is abuse prevented? No system — human or AI — can truly verify a past showup happened; a survey of industry precedent (Beeminder, Strava, Duolingo, Habitica, MyFitnessPal, Noom, Apple Fitness, Streaks/Habitify) found that no comparable app verifies past activity — the deterrent is always friction, cost, or reputation, never proof. Noom's human-coach-mediated override was the closest real-world parallel to a manual-review approach.

## Decision
All redemption requests are reviewed manually by the author for now (submitted via the About/Feedback screen, HAB-149; no new in-app entity needed). Anti-abuse relies on friction and per-pact caps, not verification.

**Revisit condition:** when the manual review load becomes unbearable, move to a technical solution — either AI-mediated conversational review, or self-attestation with friction (a cool-down period plus a per-pact redemption cap).

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Automated/AI-mediated review from the start | No system can verify a past showup happened; building verification tooling before there's real review-load pain is premature for a solo-dev, pre-launch project |
| Self-attestation with friction (cool-down + per-pact cap), immediately | Viable, but manual review is simpler to ship first and matches how comparable apps in this space actually operate (see precedent survey) |
| No redemption at all (Apple Fitness / Streaks model) | Rejected at the product level before this ticket — redemption is a defined feature; this decision is about its support workflow, not whether it exists |

## Related ticket
HAB-140 — full precedent survey and research questions: `docs/knowledge/notes/HAB-140.md`

## Date
2026-07-04
