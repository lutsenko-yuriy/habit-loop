# Backlog

Known issues and planned work that has not yet been released.

---

## Issues

- **Lazy showup generation** — showups are currently generated eagerly for the entire pact duration at creation time. This should be revisited when notifications are implemented: generating showups lazily (e.g. a rolling window ahead of today) would avoid scheduling thousands of notifications upfront and keep the repository lean. Coordinate with the notifications feature to decide the right generation horizon.
- [#6](https://github.com/lutsenko-yuriy/habit-loop/issues/6) **Refactor: reduce duplicated logic between iOS and Android dashboard widgets** — `_buildDots()` (status counting, layout, overflow colour) and the showup list/tile are duplicated verbatim across both platform pages. Extract shared logic into platform-agnostic helpers once there are enough instances to justify the abstraction.
- **Tech debt — rollback exception masks original error** (`pact_creation_view_model.dart`): if `saveShowups` fails and the compensating `deletePact` call also throws (e.g. DB locked), the rollback exception replaces the original showup error and the pact remains orphaned. **Proposed solution:** have the SQLite implementation class implement both `PactRepository` and `ShowupRepository`, giving it a single `Database` reference. It can then expose a transactional method (e.g. `savePactWithShowups(pact, showups)`) that wraps both inserts in one `db.transaction()`, eliminating the need for manual rollback in the view model. Note: simply sharing the class isn't enough — the existing `savePact()` and `saveShowups()` are separate async calls with separate implicit transactions, so a dedicated combined method is required for atomicity.
- [#2](https://github.com/lutsenko-yuriy/habit-loop/issues/2) **Refactor: replace `PactCreationState` with a `PactBuilder`** — `PactCreationState` mixes wizard navigation state with pact-building data. Extract a `PactBuilder` class that holds only the pact fields and exposes a `build()` method returning a `Pact`.

## Remaining work

- **SQLite persistence** — replace in-memory `PactRepository` and `ShowupRepository` with real `sqflite` implementations
- **Showup detail screen** — view showup time and habit name, mark as done or failed, auto-fail if the screen is opened after the scheduled showup time, leave a free-text note
- **Notifications / reminders** — schedule local notifications when a reminder offset is configured during pact creation; stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app
