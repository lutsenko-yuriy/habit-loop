# ADR-0010 — sync YAB template updates into adopted projects via a plain-git diff-and-apply workflow, not a templating tool

## Status
`accepted`

## Context
Projects that adopt the `yuriys-agentic-boyz` (YAB) template (habit_loop, mordovorot, and CheckLister next) diverge from it immediately — `setup.sh` fills in project-specific placeholders once, and each project then edits skills/docs further as it grows. YAB itself keeps improving (e.g. HAB-274's backport of 8 fixes found retrofitting mordovorot). There was no mechanism for a downstream project to know YAB had moved on, or to pull in what's new without a from-scratch manual comparison — HAB-274's backport was done entirely by hand, file by file.

Constraints (`docs/CONSTRAINTS.md`): solo developer + AI agents, prefer agent-mediated automation over ongoing manual human review; pre-public stage, optimize for simplicity over scale. YAB's own template content is markdown skills/docs plus a couple of shell/Python files — not a Jinja-templated codebase — and existing downstream repos were one-shot copied via `setup.sh`, with no ongoing git lineage to YAB.

## Decision
Adopt the core idea behind Copier's `copier update` (diff two template states, apply the diff, resolve conflicts) — implemented with plain `git`, run by an agent rather than a dedicated templating tool:

1. YAB gets a lightweight version marker (a `CHANGELOG.md` and/or git tags) — it currently has neither.
2. Each downstream project records the YAB commit/tag it last synced against.
3. A sync computes `git diff <last-synced>..<YAB HEAD>` scoped to a defined set of template-owned paths (`skills/shared/*`, the structural parts of `skills/*/*/SKILL.md`, `docs/workflows/*.md`) — explicitly excluding project-owned content (`AGENTS.md`'s filled placeholders, `docs/PRODUCT_SPEC.md`, `docs/ARCHITECTURE.md`, `CLAUDE.local.md`) — then applies it to the downstream project.
4. Conflicts surface as plain git conflict markers, resolved by the agent running the sync, with a human review pass before committing.

No new dependency (Copier/cookiecutter/cruft/Yeoman) is adopted — our content is markdown, not a Jinja-templated codebase, so their machinery (answers files, Jinja rendering) would be pure retrofit cost with no matching benefit. Scripting this as a dedicated `/sync-yab`-style skill is a candidate follow-up implementation ticket, not required immediately — the same diff-and-apply steps are already usable manually by an agent today.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Copier (`copier update`) | Strongest ecosystem precedent (answers-file + double-regeneration diff + 3-way merge — [docs](https://copier.readthedocs.io/en/stable/updating/)), but requires adopting Jinja templating and an answers-file model YAB doesn't have. Real retrofit cost for content that's already plain markdown. |
| cruft (bolt-on for cookiecutter) | Same retrofit problem, plus its skip-list-only divergence handling ([docs](https://cruft.github.io/cruft/)) is coarser than needed — many YAB files (e.g. `AGENTS.md`) mix template and project content within the same file, not cleanly separable by path alone. |
| Yeoman generator re-run | Wrong ecosystem (Node generator model); whole-file overwrite-or-skip granularity, no line-level merge — documented ([generator#966](https://github.com/yeoman/generator/issues/966)) to clobber user-added code in practice. |
| Framework-native diff viewer (Rails `app:update`, React Native Upgrade Helper) | Diffs two template states but leaves *application* into the diverged project fully manual — RN's Upgrade Helper has no apply step at all. Contradicts the "prefer agent-mediated automation" constraint; practitioners ([FastRuby.io](https://www.fastruby.io/blog/why-you-might-not-want-to-run-rails-app-update.html)) explicitly warn against trusting Rails' automated prompt. |
| Git subtree/submodule | Generic history-merge, not template-aware — no distinction between template-owned and project-owned content. Would require retroactively establishing a git lineage the existing sibling repos don't have, and real-world usage needs bespoke wrapper tooling (e.g. [Cumulus's subtree workflow](https://github.com/paritytech/cumulus/blob/master/BRIDGES.md)) — heavier than warranted at this scale. |
| Do nothing (keep the current ad hoc manual approach) | Worked at N=2 downstream projects and a handful of fixes (HAB-274), but doesn't scale as YAB accumulates changes and more projects adopt it — no way even to detect drift, let alone apply it. |

## Related ticket
HAB-276

## Date
2026-09-16
