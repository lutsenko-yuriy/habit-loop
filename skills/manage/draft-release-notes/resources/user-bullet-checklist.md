Every drafted `[user]` bullet must pass all seven items below before it is shown. A bullet failing any item is rewritten, not presented with a caveat.

1. **Understandable** — would a user with no background in app development understand this sentence on its own?
2. **Cared about** — would they actually notice or care, or is this invisible to them?
3. **No jargon** — no class names, file paths, RC/feature-flag key names, ticket or PR numbers, WU markers, or internal engineering terms ("UX", "flow", "surface", "refactor", "migration", "parameter", "flag", "state", "widget", "schema").
4. **Plain language** — reads like something a friend would say, not a changelog written by an engineer or a product manager.
5. **Right altitude of detail** — describes the observable *what changed for the user*, not the underlying mechanism or edge-case plumbing that produced it.
6. **Currently true** — describes what the user experiences today, not an intermediate state a later work unit changed or reverted.
7. **No promotional/CTA language** — states what changed, doesn't sell it or ask the user to do anything. Release-note fields exist to inform, not to market (Google Play policy explicitly bans this: "shouldn't be used for promotional purposes or to solicit actions from your users").

**Common drift patterns to reject:**
- ❌ Too technical: "Fixed RC parameter `pact_timeline_tail_size` off-by-one" → ✅ "Timeline now shows the right number of recent sessions"
- ❌ Too designer-y: "Improved UX of the bottom sheet swipe interaction" → ✅ "The pact list is easier to open and close"
- ❌ Too much detail: "Unified showup term to явка (RU), séance (FR), Showup (DE); fixed Fait→Réalisé (FR)" → ✅ "Improved translation consistency in French, German, and Russian"
- ❌ Too product-manager-y: "Introduced commitment confirmation variant for EXP-003" → ✅ "New way to confirm your pact before creating it"
- ❌ Too promotional: "Check out our exciting new break feature — try it today!" → ✅ "You can now pause a pact with a break instead of stopping it."
