# Project Constraints

Standing constraints to reference when evaluating trade-offs — especially in research tickets.

## Team & capacity

- **Solo developer + AI agents.** No dedicated support team, QA team, or second reviewer.
- **Agent resources are available; human support capacity is not.** Solutions that require ongoing human review must be sustainable by one person. When load grows, prefer agent-mediated automation over hiring.

## Stage

- **Pre-public launch.** User base is small; optimise for simplicity and reversibility over scalability. Defer infrastructure that only pays off at scale.
- **No store-review gate yet.** Builds ship to testers multiple times a day via Firebase App Distribution, with no app-store review delay. Anything justified primarily by "faster than a store release" should be re-evaluated once the app moves to real store distribution.
