---
name: describe-feature
effort: FOCUSED
reasoning: ARCHITECTURAL
output_style: CONCISE
description: Guide the user through articulating a rough feature idea and turn it into a properly scoped Linear ticket. Reads the product spec and glossary, engages in an iterative clarifying dialog (one question at a time), then creates the ticket and updates the glossary. Invoked from the summarize flow when the user wants to describe something new rather than pick up an existing ticket.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

Linear workspace IDs:
- Team ID: `2de84a9b-453b-4991-8e09-f88715fa926e`
- Project ID: `c3afdc26-d306-4f72-bdb3-de9b01060d0f`

This skill produces a ticket, not code.

---

## Steps

### 1. Read product context

Read the following files in full before asking the user anything:

- `docs/PRODUCT_SPEC.md` — what the app currently does
- `docs/GLOSSARY.md` — canonical domain terms and known aliases

This context is the reference against which the user's idea will be validated.

### 2. Open the dialog

Ask the user to describe their feature idea in their own words. One open question is enough:

> "Tell me about the feature you have in mind."

### 3. Iterate — one question at a time

**Spirit of the dialog:** the goal is mutual clarity — the user ends the conversation with a shared, unambiguous picture of what they want to build. Asking a hard question or flagging a contradiction is expected and helpful. But every challenge must read as *help*, not judgement. Name the problem, not a verdict. Frame contradictions as open questions, not blockers. If the user's direction is unclear, ask in order to understand — not in order to correct.

**Examples:**

| Instead of… | Say… |
|---|---|
| "That won't work." | "This overlaps with the existing pact-end flow — how should they interact?" |
| "You can't have both — they contradict each other." | "You mentioned X earlier and now Y — I'm not sure how to reconcile them. Which takes priority?" |
| "That's not what a pact is in this app." | "When you say 'goal', do you mean the same thing as a pact, or something different?" |

**Staying on topic:** the dialog has a clear goal — a scoped ticket. If the conversation drifts (the user starts discussing unrelated ideas, broader strategy, or goes off on a tangent), gently acknowledge what was said and redirect: "That's interesting — let's note it and come back. For now, can we finish pinning down [the feature we started with]?" Do not chase tangents, even interesting ones.

After each user response, do exactly one of the following:

- **Ask one clarifying question** — if anything is ambiguous, undefined, or contradicts the spec or glossary. Do not ask multiple questions at once.
- **Flag a contradiction** — if the idea conflicts with existing product behaviour, name the conflict and ask how the user wants to resolve it.
- **Flag an undefined term** — if the user introduces a term not in `docs/GLOSSARY.md`, ask them to define it before continuing.
- **Proceed to step 4** — if the idea is clear, coherent, and non-contradictory.

The dialog is **product-level only**: no architecture, no implementation details, no data models. The goal is clarity on *what* and *why*, not *how*.

If at any point the user signals abandonment ("I guess we don't need it", "let's postpone", "forget it", or similar), jump to step 6.

### 4. Create the ticket

Once the idea is clear, create a Linear issue with `mcp__linear__save_issue`:

- `team`: `2de84a9b-453b-4991-8e09-f88715fa926e`
- `project`: `c3afdc26-d306-4f72-bdb3-de9b01060d0f`
- `title`: concise noun-phrase title
- `labels`: `["Feature"]`
- `priority`: 3 (Medium) unless the user indicated otherwise
- `description`: use the template below

**Ticket description template:**

```markdown
## User story

As a <role>, I want <action> so that <outcome>.

## Behaviour

<bullet list of observable behaviours — what the user sees and can do>

## Out of scope

<explicit list of things this ticket does NOT cover>

## Open questions

<any remaining ambiguities, or "None" if fully resolved>
```

Fill every section. "Out of scope" must always be present — even if short — to prevent scope creep.

### 5. Update the glossary (if new terms were introduced)

If the dialog produced any new domain terms not already in `docs/GLOSSARY.md`, add them now.

Open `docs/GLOSSARY.md`, locate the correct alphabetical position, and insert entries following the existing format. Do not remove or reorder existing entries.

### 6. Report back

Tell the user:

- The ticket ID and URL
- Any glossary additions (term + definition), or "no glossary changes" if none

If the user abandoned in step 3:

- Summarise what was unclear or contradictory (2–4 bullet points)
- State that no ticket was created
- Stop

---

## Constraints

- Never ask more than one question per turn.
- Never discuss implementation, architecture, or data models.
- Never create a ticket until the idea is unambiguous and coherent.
- Never update `docs/PRODUCT_SPEC.md` — that is deferred to HAB-119.
- Never update `docs/BACKLOG.md` or `docs/CHANGELOG.md` — those are owned by the `ship` skill.
