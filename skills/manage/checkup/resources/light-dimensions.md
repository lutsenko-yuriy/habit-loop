# Light-tier dimensions

Due the 1st of every calendar month, tracked as "not yet done this month" — see [ADR-0003](../../../../docs/knowledge/decisions/ADR-0003-two-tier-periodic-code-quality-checkup.md). Walk these five in order.

## 1. Unused functionality

Run `/dead-code-check` and fold its `[WARN]` sections in (orphaned l10n keys, analytics event classes, test files, handler files). Cross-check `docs/ANALYTICS_EVENTS.md` for events defined but never fired, and feature-flag-gated entry points shipped but seemingly unused. As product owner, question features that may not earn their keep.

*Grounding: product-analytics "kill condition" practice — doesn't retroactively help shipped features but surfaces retirement candidates ([Userpilot](https://userpilot.com/blog/product-feature-analysis/)).*

## 2. Scenario quality

Review `integration_test/` scenarios: do they still map to current `docs/PRODUCT_SPEC.md` flows? Any skipped/commented/`TODO` scenarios, redundant overlap, or assertions that assert nothing meaningful?

*Grounding: internal heuristic tied to `/draft-scenarios` conventions — no strong external precedent, noted as such.*

## 3. Glossary/naming drift

Diff `docs/GLOSSARY.md` canonical terms and known aliases against current code identifiers and UI strings; flag code terms absent from the glossary and aliases that crept back in.

*Grounding: DDD ubiquitous-language drift is expected as implementation solidifies — the glossary needs periodic review, not a one-time write ([Fowler: Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html)).*

## 4. Doc-reality drift

Sampled read of `docs/ARCHITECTURE.md`, `docs/PRODUCT_SPEC.md`, `docs/FEATURE_TOGGLES.md`, `docs/ANALYTICS_EVENTS.md`, and `docs/VERSIONING.md` against current code: do described flags, events, and layers still exist and match? Sampled, not exhaustive — mechanical staleness detection is out of scope.

*Grounding: docs-as-code staleness detection normally assumes CI/mechanical enforcement, which doesn't fit a solo-dev monthly cadence ([Docsie](https://www.docsie.io/blog/glossary/documentation-drift/)).*

## 5. Feature-flag lifecycle

For each flag in `docs/FEATURE_TOGGLES.md` and `RemoteConfigDefaults.all`: still needed? how old? assign or verify a review-by date; flag stale kill-switches for removal.

*Grounding: feature-flag audit practice — an explicit per-flag expiration/review-by date, because stale flags compound ([Statsig](https://www.statsig.com/perspectives/tips-for-unused-feature-flag-clean-up) · [FlagShark](https://flagshark.com/blog/feature-flag-lifecycle-creation-cleanup-5-stages/)).*
