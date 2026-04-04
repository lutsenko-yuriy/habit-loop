# Backlog

Known issues and planned work that has not yet been released.
This file is generated from Linear — do not edit by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).

---

## Issues

- [HAB-14](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-14/tech-debt-lazy-showup-generation) **Tech debt: lazy showup generation** — Showups are currently generated eagerly for the entire pact duration at creation time. Should be revisited when notifications are implemented: generate lazily (rolling window ahead of today) to avoid scheduling thousands of notifications upfront and keep the repository lean.
- [HAB-15](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-15/refactor-reduce-duplicated-iosandroid-dashboard-widget-logic) **Refactor: reduce duplicated iOS/Android dashboard widget logic** — `_buildDots()` (status counting, layout, overflow colour) and the showup list/tile are duplicated verbatim across both platform pages. Extract shared logic into platform-agnostic helpers once there are enough instances to justify the abstraction. GitHub: #6
- [HAB-16](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-16/tech-debt-rollback-exception-masks-original-error-in-pact-creation) **Tech debt: rollback exception masks original error in pact creation** — In `pact_creation_view_model.dart`: if `saveShowups` fails and the compensating `deletePact` call also throws, the rollback exception replaces the original error and the pact remains orphaned. Fix: the SQLite implementation should implement both `PactRepository` and `ShowupRepository` and expose a `savePactWithShowups()` transactional method wrapping both inserts in one `db.transaction()`.
- [HAB-17](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-17/refactor-replace-pactcreationstate-with-a-pactbuilder) **Refactor: replace PactCreationState with a PactBuilder** — `PactCreationState` mixes wizard navigation state with pact-building data. Extract a `PactBuilder` class that holds only the pact fields and exposes a `build()` method returning a `Pact`. GitHub: #2

## Remaining work

- [HAB-11](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-11/sqlite-persistence-replace-in-memory-repositories) **SQLite persistence — replace in-memory repositories** — Replace `InMemoryPactRepository` and `InMemoryShowupRepository` with real `sqflite` implementations so pacts and showups survive app restarts. The SQLite class should implement both repository interfaces and expose a `savePactWithShowups()` transactional method to fix the rollback tech debt (see related issue).
- [HAB-12](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-12/showup-detail-screen) **Showup detail screen** — New screen reachable from the dashboard showup list. Shows showup time and habit name; lets the user mark the showup as done or failed; auto-fails if the screen is opened after the scheduled time; allows leaving a free-text note at any time.
- [HAB-13](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-13/notifications-and-reminders) **Notifications and reminders** — Schedule local notifications when a reminder offset is configured during pact creation. Stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app. Coordinate with lazy showup generation — decide the right generation horizon before scheduling thousands of notifications upfront.
- [HAB-18](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-18/create-reusable-claude-multi-agent-project-template) **Create reusable Claude multi-agent project template** — Extract the Claude agent setup from this project into a standalone GitHub template repository, so the same multi-agent workflow (Product Owner, Tech Lead, Developer, Code Reviewer + Linear MCP) can be bootstrapped for any new project.
