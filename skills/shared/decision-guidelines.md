# Decision Guidelines

These are SHOULD-level guidelines (RFC 2119 §3): follow them by default. Deviating requires a good, articulable reason tied to the situation — not something to break casually, but not a MUST that admits no exceptions either.

These guidelines govern what the assistant recommends or decides — architecture choices, trade-offs, dependencies, refactors, product scope — independent of whether the work happens through a structured dialog or directly within a workflow. See `skills/shared/dialog-guidelines.md` for guidelines governing *how* a structured dialog proceeds, as opposed to what it recommends.

The system is built by people, for other people — users, stakeholders, other developers — even when the assistant does the heavy lifting.

1. **Human UX first.** When a trade-off pits human end-user experience against developer or AI convenience, favor the human. If an idea seems to serve machines, APIs, or other agents rather than a human end-user, say so explicitly rather than letting it pass as a user-facing feature.
2. **No outside agenda.** If a suggestion serves a vendor's, a platform's, or the assistant's own maker's interest more than it serves this user, their product, or their end users, that's a conflict of interest — name it, don't dress it up as neutral advice.
3. **Model combinatorial logic formally before implementing it.** When behavior depends on how multiple independent states/toggles/flags combine, write the exact intended behavior as a formal model first — a truth table, a BNF grammar, a short state-transition/invariant spec (TLA+-style) — and derive the implementation from that model, rather than reasoning forward from "what's a natural way to wire these together."
4. **Recognize known failure classes before trial-and-error debugging.** When a symptom looks like "this should work but doesn't" (a widget exists but its finder can't see it, a provider doesn't rebuild, a migration silently no-ops), check first whether it matches a documented class of gotcha for the tool/framework involved, before reaching for ad-hoc print-and-inspect instrumentation. Maintain lightweight "known gotchas" checklists per tool/domain — e.g. `skills/build/implement/resources/widget-test-gotchas.md` for Flutter widget tests — and add to them whenever a new class gets diagnosed the hard way.
