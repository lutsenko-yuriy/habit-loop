# ADR-0009 — recommend building a grep-based "oracle" Q&A skill for docs/skills/notes; reject a generated doc-graph and wikilink adoption

## Status
`accepted`

## Context
HAB-253 (follow-up from the HAB-220 debrief, 2026-08-25) asked whether the human's experience
navigating the `docs/`/`skills/` corpus (146 docs `.md`, 47 skills `.md`, 106
`docs/knowledge/notes/*.md`, ~14k lines total) could be improved, distinct from HAB-220's
agent-context-token work. Two directions were in scope: (1) wiki-style navigation aids
(bidirectional linking, doc graphs, generated topic maps), and (2) a dedicated "oracle" skill
that answers a question directly from the corpus instead of requiring manual file reading.

Survey of existing tools (HAB-253 session, 2026-09-09): Obsidian/Foam/Dendron-style
`[[wikilink]]` backlinks auto-derive from link syntax with no ongoing manual upkeep, but
require retrofitting bracket-link syntax across the whole corpus and are built for a
vault-browsing UI this repo's CLI/agent-first workflow doesn't use
([Obsidian backlinks](https://deepwiki.com/obsidianmd/obsidian-help/4.2-internal-links-and-backlinks)).
A `madge`-style graph generator ([piuccio/madge](https://github.com/piuccio/madge)) can run
directly on this repo's existing plain `[text](path.md)` links with no retrofit, but only
yields a browsable diagram — it doesn't answer questions. Retrieval/Q&A tools range from
heavyweight org-scale platforms (Glean, Notion AI) that assume a dedicated docs/search team
down to a grep-plus-LLM-synthesis pattern with no vector database
([AlterLab RAG-with-Markdown](https://alterlab.io/blog/build-a-token-efficient-rag-pipeline-with-pgvector-markdown)
describes the heavyweight end) — the cheap end of that spectrum is exactly the pattern this
repo's own `/research` and `/summarize` skills already use (grep/read files, then synthesize).

Constraint fit (`docs/CONSTRAINTS.md`): solo developer, no dedicated docs team, pre-launch
stage favoring simplicity and reversibility. Wikilink retrofit fails this — a one-time
193-file rewrite for a vault-browser payoff nobody here uses. A generated doc graph is cheap
to build but only helps *browsing* structure, not *answering* a question — and this repo
already has a working precedent for structure-only navigation
(`docs/knowledge/notes/INDEX.md` via `scripts/notes/index.py`, scoped to notes only) plus a
hand-maintained front door (`CLAUDE.md`'s Documentation/Skills tables) that already covers
docs/skills at the file level. The oracle skill directly addresses the "tiresome"/"heavy to
carry in the head" complaint from the HAB-220 debrief by removing the need to hold the corpus
in memory at all for question-shaped needs, at near-zero infra cost.

## Decision
Recommend building a dedicated "oracle" skill (follow-up ticket, not part of HAB-253's
research scope) that takes a natural-language question, searches `docs/`, `skills/`, and
`docs/knowledge/notes/` (grep/ripgrep for candidate files, then reads and synthesizes an
answer with file-path citations — no vector database, no persisted index), and states
plainly when the corpus doesn't contain a clear answer rather than guessing. Do not adopt
wikilink-style bidirectional linking, and do not build a generated doc-graph/backlink script
for `docs/`+`skills/` at this time — both are deferred as insufficiently justified by the
current corpus size and solo-developer context.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Wikilink/backlink adoption (Obsidian/Foam/Dendron-style) | Requires retrofitting `[[wikilink]]` syntax across 193 files for a vault-browsing payoff; this repo's docs are read via CLI/agent, not a wiki app — poor fit for the actual reading context. |
| Generated doc-graph script (madge-style, over existing markdown links) | Cheap to build and would extend the existing notes-INDEX precedent, but only aids browsing structure, not answering questions — doesn't address the "tiresome to read/hold in the head" complaint as directly as a Q&A skill, and the user did not select it when offered alongside the oracle skill. |
| Oracle skill + doc graph (both) | Doc graph adds a second follow-up ticket's worth of scope without addressing a distinct enough need once the oracle skill exists; user chose oracle-only. |
| Status quo (no new tooling) | CLAUDE.md's hand-maintained tables and ripgrep already work as file-level navigation, but do nothing for "answer this question without reading multiple files," which was the ticket's explicit second ask. |
| Heavyweight RAG / enterprise search (Glean, Notion AI-style) | Assumes a dedicated docs/search team, connector infrastructure, and org-scale query volume — wrong scale for a solo developer with a ~14k-line corpus. |

## Related ticket
HAB-253

## Date
2026-09-09
