# Backlog

Known issues and planned work that has not yet been released.
This file is generated from Linear — do not edit by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).

---

## Issues

- **[IUR-14] Tech debt: lazy showup generation** — showups are generated eagerly for the full pact duration; revisit when notifications are implemented to use a rolling window instead. (Tech Debt)
- **[IUR-15] Refactor: reduce duplicated iOS/Android dashboard widget logic** — `_buildDots()` and showup list/tile are duplicated verbatim across both platform pages; extract shared helpers once the abstraction is justified. (Tech Debt) — [GitHub #6](https://github.com/lutsenko-yuriy/habit-loop/issues/6)
- **[IUR-16] Tech debt: rollback exception masks original error in pact creation** — if `saveShowups` fails and `deletePact` also throws, the rollback exception replaces the original error and the pact is orphaned; fix with a single `savePactWithShowups()` transaction in the SQLite implementation. (Tech Debt)
- **[IUR-17] Refactor: replace `PactCreationState` with a `PactBuilder`** — `PactCreationState` mixes wizard navigation state with pact-building data; extract a `PactBuilder` with a `build()` method. (Tech Debt) — [GitHub #2](https://github.com/lutsenko-yuriy/habit-loop/issues/2)

## Remaining work

- **[IUR-11] SQLite persistence** — replace `InMemoryPactRepository` and `InMemoryShowupRepository` with real `sqflite` implementations so data survives app restarts. (Feature)
- **[IUR-12] Showup detail screen** — view showup time and habit name, mark as done or failed, auto-fail if opened after scheduled time, leave a free-text note. (Feature)
- **[IUR-13] Notifications and reminders** — schedule local notifications for configured reminder offsets; stretch goal: actionable notifications on iOS and Android. (Feature)
