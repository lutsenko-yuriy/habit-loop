# ADR-0006 — adopt the "test robot" pattern incrementally, starting from the next flaky-file fix, plus a centralized widget-Key file

## Status
`accepted`

## Context
Integration scenarios in `integration_test/` hand-roll `find`/`pump`/`ensureVisible`/`tap` sequences per screen, directly in each test. Screen-specific timing quirks (keyboard-inset relayout races, lazy-list scroll realization) get independently rediscovered per file that touches the same screen — HAB-199 spent ~9 CI dispatches on one such race, and HAB-258 rediscovered a related class of race in a different file months later, despite both being logged in `skills/build/implement/resources/widget-test-gotchas.md`. HAB-258's own fix already followed the shape of a "robot" in substance (shared, intention-revealing helpers like `_waitForNoteSaved`, `_enterNoteText` inside the test file) without lifting that logic into a reusable class — the pattern was reinvented ad hoc rather than adopted as a standing convention. Constraints: solo developer with no dedicated test-infra owner (`docs/CONSTRAINTS.md`), pre-launch stage favoring simplicity and reversibility over up-front infrastructure.

## Decision
Adopt the Flutter-community "test robot" pattern (one helper class per screen, or per closely-related screen group, exposing intention-revealing methods that wrap the find/pump/scroll/tap/settle sequence) **incrementally**, not as an up-front migration: new robot classes are written under `integration_test/robots/` only when touching a screen during future feature or fix work, starting with `pact_note_flow_test.dart`'s helpers (tracked under HAB-267) as the first real instance. Existing passing flow tests are left as-is unless they're touched anyway. Separately, adopt a centralized widget-`Key` file shared between app code and test code (per LeanCode/Patrol's discussion-based convention) to remove key-typo bugs — this is orthogonal to the robot pattern and cheap enough to fold in whenever convenient, not gated on it.

## Alternatives considered
| Option | Why not chosen |
|---|---|
| Full upfront migration of all 20 flow tests to robot classes | Large, low-value diff with no immediate bug behind it; violates "optimize for simplicity, defer infra that only pays off at scale" under solo-dev capacity |
| Status quo — keep relying on the `widget-test-gotchas.md` checklist, fix races ad hoc per file | Already demonstrated to fail: the checklist didn't prevent HAB-258 from rediscovering a known race class; costs ~90 min to ~10 CI cycles per incident, repeatedly |
| Centralized widget-Key file only, no robot classes | Solves a smaller, different problem (typo-class key bugs) — doesn't address the actual timing-race pain point that motivated this research (HAB-199, HAB-258) |

## Related ticket
HAB-200

## Date
2026-09-06
