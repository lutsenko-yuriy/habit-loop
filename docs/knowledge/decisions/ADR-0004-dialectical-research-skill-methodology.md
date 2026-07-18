# ADR-0004 — build a single-pass dialectical (thesis/antithesis/synthesis) research skill, steelman-bounded, over six other candidate methodologies

## Status
`accepted`

## Context
HAB-123 originally proposed a `research` skill using a dialectical (thesis →
antithesis → synthesis) design. A ticket comment flagged six alternative
methodologies (systematic literature review, scoping review, plain adversarial
prompting, steelman search, SWOT-style framing, expert consensus mapping)
worth weighing before committing to that framing. The ticket was rescoped to
compare all seven against `docs/CONSTRAINTS.md` (solo developer + AI agents,
no dedicated reviewer, pre-public-launch — optimise for simplicity and
reversibility) and against real precedent, per `docs/RESEARCH_WORKFLOW.md`.

Full survey, citations, and trade-off ranking: `docs/knowledge/notes/HAB-123.md`.

## Decision
Build one skill: single-pass dialectical research with steelman-bounded
evidence. Concretely — restate the user's claim as a thesis and generate the
strongest antithesis; research each branch in parallel (two subagents,
WebSearch/WebFetch plus free academic APIs); cap each branch's evidence table
at 3–5 best sources (URL, quote, quality line); run exactly one synthesis pass
that may only cite rows already in those tables. No iterated debate rounds.
For a bare topic (no claim to oppose), the skill degrades to a scoping-style
map instead of manufacturing a fake thesis.

Implementation (the skill file itself, plus the `docs/RESEARCH_WORKFLOW.md`
integration and `AGENTS.md` slash-command entry) is explicitly out of scope
for HAB-123 — tracked as a separate follow-up ticket, to be created only if
implementation is approved.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Plain adversarial prompting (the ticket's original fallback recommendation) | Stops at two unreconciled lists; reconciling them is exactly the human-review step the constraints say doesn't exist. |
| Steelman search | Single-source-per-side risks cherry-picking as a standalone method; adopted instead as a bounding rule inside the dialectical design. |
| Scoping review | Right fit for topic-mapping inputs, but yields no verdict on a claim — used only as the bare-topic degradation mode. |
| Expert consensus mapping | Needs index-scale retrieval (200M+ papers) to be honest, or else generates consensus from model priors rather than literature — unauditable by a solo reviewer. |
| Systematic literature review | ~67-week human baseline; PRISMA completeness is unmeetable with WebSearch + free APIs — a report that looks PRISMA-grade but isn't is the worst outcome under a no-reviewer constraint. |
| SWOT-style framing | Precedent is strategy/product analysis, not truth-evaluation of factual claims — category mismatch. |
| Multi-round dialectical (iterated debate) | Documented to erode up to 72% of issue-critical facts and homogenise stances across rounds — the single-pass constraint avoids this failure mode. |
| Build nothing (status quo ad-hoc search) | No forced-opposition step — exactly the sycophancy failure mode (models agreeing with the user's stated position) the skill exists to counter. |

## Related ticket
HAB-123

## Date
2026-07-18
