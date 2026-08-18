# ADR-0005 — keep the per-PR/per-ticket release model; do not batch tickets into shared releases

## Status
`accepted`

## Context
HAB-240 asked whether releases should batch multiple tickets together — motivated by
solo-dev + AI-agent scale and a hypothetical small-team (≤6-dev) scale — instead of the
current model where each merged PR is its own potential release (`docs/VERSIONING.md`).

`docs/CONSTRAINTS.md` fixes this project as solo-dev + pre-public-launch, with no
app-store review gate: builds ship to testers multiple times a day via Firebase App
Distribution/TestFlight, with no serialized human QA or store-review delay standing
between a merge and a release.

External scoping survey (four sources, one unverified) found no source supporting
batching at this scale, and the strongest source argued the opposite: DORA's "Working in
Small Batches" frames small batch size as an empirically-validated predictor of delivery
performance and explicitly as a safety net for AI-assisted development — batching before
release delays defect feedback and widens blast radius. GitLab's release-train design
solves a problem (long, serialized per-release QA/build cycles) this project's pipeline
doesn't have. Jonathan Hall's solo-dev guidance splits by artifact type; this app's
actual distribution behavior (frequent pushes, no store gate) matches his
continuous-deploy case rather than his batched-release case, despite being a mobile app.

Full survey, citations, and question-by-question notes: `docs/knowledge/notes/HAB-240.md`.

## Decision
Keep the current per-PR/per-ticket release model unchanged. No `docs/VERSIONING.md`
changes. The ≤6-dev-team question (Q2) is left unevaluated by design — it's contingent
on this decision going the other way, and `docs/CONSTRAINTS.md` already says to defer
infrastructure that only pays off at a scale not yet reached. Revisit if team size or
release cadence materially changes.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Batch N tickets into one release (extend HAB-185's `## [Unreleased]` mechanism to `[user]`/`[app]` entries, add an explicit release-cut trigger) | No surveyed source supports it at this scale; strongest source (DORA) argues against it; would trade away the project's real fast-feedback advantage (no store-review gate) for no identified benefit. |
| Release trains (GitLab-style scheduled cadence) | Solves serialized per-release QA/build cost this project's pipeline doesn't have (~10-20 min CI, no human QA gate, no store review). |

## Related ticket
HAB-240

## Date
2026-08-18
