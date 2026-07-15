# ADR-0001 — adopt the MIT licence for the repository

## Status
`accepted`

## Context
As of June 2026 the project had no explicit licence: solo developer, no contributors planned, public GitHub repo, no commercial plans, primary use case is sharing with colleagues. Without an explicit licence, copyright law defaults to "all rights reserved" even for a public repo — colleagues could not legally reuse or study the code. The codebase is also largely AI-generated; copyright requires human authorship, and how much human authorship AI-assisted code retains is an open legal question, making a strong proprietary claim shakier than for hand-written code. All direct and notable transitive dependencies were audited and found permissive (MIT/BSD-2/BSD-3/Apache-2.0) — no copyleft dependency blocks a permissive choice.

## Decision
Adopt the **MIT licence**. Source licence and App Store distribution are independent — an MIT-licensed codebase can still be compiled and distributed as a proprietary app with no conflict.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Apache 2.0 | Strong second choice — adds an explicit patent grant, but the NOTICE file requirement is extra overhead not justified by the project's needs |
| GPL v2 | Ruled out — incompatible with Apache-2.0 transitive dependencies (`fake_async`, `clock`, `material_color_utilities`) |
| Proprietary / no licence | Not recommended — legally prevents colleagues from reusing or studying the code even though the repo is public; shakier footing given the AI-generated-code authorship question |

## Related ticket
HAB-109 — full licence-family research, dependency compatibility audit, and AI-copyright analysis: `docs/knowledge/notes/HAB-109.md`

## Date
2026-07-04
