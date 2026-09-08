# Project Constraints

Standing constraints to reference when evaluating trade-offs — especially in research tickets.

## Team & capacity

- **Solo developer + AI agents.** No dedicated support team, QA team, or second reviewer.
- **Agent resources are available; human support capacity is not.** Solutions that require ongoing human review must be sustainable by one person. When load grows, prefer agent-mediated automation over hiring.

## Stage

- **Pre-public launch.** User base is small; optimise for simplicity and reversibility over scalability. Defer infrastructure that only pays off at scale.
- **No store-review gate yet.** Builds ship to testers multiple times a day via Firebase App Distribution, with no app-store review delay. Anything justified primarily by "faster than a store release" should be re-evaluated once the app moves to real store distribution.

## Devices

- **Real iOS/Android devices are only available during the In QA phase.** During development, only virtual devices (simulators/emulators) are on hand. The Android emulator lets you change system time to trigger scheduled notifications reliably; the iOS Simulator's local-notification firing is unreliable when the clock is forced forward — so during development, notification verification is limited to confirming a notification is scheduled (e.g. via the debug Pending Notifications screen), with actual on-device delivery checks deferred to the In QA human-device pass (HAB-246 debrief).
- **A Debug build cannot be relaunched by tapping its icon on a ProMotion device (iPhone 14 Pro or later).** Cold-starting a Debug build without a debugger attached — which is exactly what happens after a force-quit, or after iOS reclaims a long-backgrounded scene — crashes with `EXC_BAD_ACCESS` in the Flutter engine's `VSyncClient` init. This is an unresolved upstream Flutter engine bug (HAB-271; matches flutter/flutter#183900), not an app bug, and never affects Release/TestFlight builds. Always relaunch a Debug build via `flutter run`/Xcode, never by tapping the home-screen icon, when testing on such a device.
