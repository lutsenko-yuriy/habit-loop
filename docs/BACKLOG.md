# Backlog

Known issues and planned work that has not yet been released.
This file is generated from Linear — do not edit by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).

---

## Issues

- [HAB-22](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-22/auto-refresh-dashboard-when-date-changes-at-midnight) **Auto-refresh dashboard when date changes at midnight** — `nowProvider` is evaluated once and not invalidated while the app stays open; after midnight the calendar strip still shows the previous day as "today" and new showups are not generated until relaunch. (Tech Debt / Feature)
- [HAB-24](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-24/replace-day-7-date-arithmetic-with-dateadddurationdays-7) **Replace `day + 7` date arithmetic with `date.add(Duration(days: 7))`** — Two places use `DateTime(year, month, day + 7)` which works but is non-obvious and inconsistent with the project's `_addMonths()` pattern; replace with `date.add(Duration(days: 7))` for clarity. (Tech Debt)
- [HAB-16](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-16/tech-debt-rollback-exception-masks-original-error-in-pact-creation) **Tech debt: rollback exception masks original error in pact creation** — In `pact_creation_view_model.dart`: if `saveShowups` fails and the compensating `deletePact` call also throws, the rollback exception replaces the original error and the pact remains orphaned. Fix: wrap both inserts in a single `db.transaction()`. (Tech Debt)
- [HAB-17](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-17/refactor-replace-pactcreationstate-with-a-pactbuilder) **Refactor: replace PactCreationState with a PactBuilder** — `PactCreationState` mixes wizard navigation state with pact-building data. Extract a `PactBuilder` class that holds only the pact fields and exposes a `build()` method returning a `Pact`. (Tech Debt)
- [HAB-15](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-15/refactor-reduce-duplicated-iosandroid-dashboard-widget-logic) **Refactor: reduce duplicated iOS/Android dashboard widget logic** — `_buildDots()` (status counting, layout, overflow colour) and the showup list/tile are duplicated verbatim across both platform pages. Extract shared logic into platform-agnostic helpers once there are enough instances to justify the abstraction. (Tech Debt)

## Remaining work

- [HAB-11](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-11/sqlite-persistence-replace-in-memory-repositories) **SQLite persistence — replace in-memory repositories** — Replace `InMemoryPactRepository` and `InMemoryShowupRepository` with real `sqflite` implementations so pacts and showups survive app restarts. The SQLite class should implement both repository interfaces and expose a `savePactWithShowups()` transactional method to fix the rollback tech debt. (Feature)
- [HAB-13](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-13/notifications-and-reminders) **Notifications and reminders** — Schedule local notifications when a reminder offset is configured during pact creation. Stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app. Coordinate with lazy showup generation. (Feature)
- [HAB-20](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-20/organize-uploading-builds-to-firebase) **Organize uploading builds to Firebase** — Upload iOS and Android builds so they can be delivered to the devices of users who agreed to be testers.
- [HAB-21](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-21/auto-fail-past-due-showups-on-dashboard-load) **Auto-fail past-due showups on dashboard load** — When the dashboard loads or refreshes, any showup whose scheduled window has passed (`now > scheduledAt + duration`) and is still `pending` should be automatically transitioned to `failed` and persisted. Blocked by HAB-13. (Feature)
