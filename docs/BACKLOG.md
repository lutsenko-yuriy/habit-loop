# Backlog

Known issues and planned work that has not yet been released.
Most of this file is generated from Linear — do not edit the milestone and unscheduled sections by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).
The `## In Progress` section at the top is the one exception — it is maintained manually by agents as part of the single-ticket-in-progress workflow.

---

## In Progress

_(nothing in progress)_

---

## v1.0.0 — SQLite persistence + pre-persistence cleanup

### Issues

- [HAB-16](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-16/tech-debt-rollback-exception-masks-original-error-in-pact-creation) **Tech debt: rollback exception masks original error in pact creation** — Resolved as part of HAB-11: wrap pact and showup inserts in a single `db.transaction()` via `savePactWithShowups()`. (Tech Debt — blocked by HAB-11)
- [HAB-22](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-22/auto-refresh-dashboard-when-date-changes-at-midnight) **Auto-refresh dashboard when date changes at midnight** — `nowProvider` is evaluated once and not invalidated while the app stays open; after midnight the calendar strip still shows the previous day as "today" and new showups are not generated until relaunch. On foreground resume, invalidate `nowProvider` if the date has changed; stretch goal: midnight background trigger coordinated with HAB-13. (Tech Debt / Feature — blocked by HAB-13)

### Remaining work

- [HAB-11](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-11/sqlite-persistence-replace-in-memory-repositories) **SQLite persistence — replace in-memory repositories** — Replace `InMemoryPactRepository` and `InMemoryShowupRepository` with real `sqflite` implementations so pacts and showups survive app restarts. The SQLite class should implement both repository interfaces and expose a `savePactWithShowups()` transactional method, fixing the rollback tech debt. (Feature)
- [HAB-13](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-13/notifications-and-reminders) **Notifications and reminders** — Schedule local notifications when a reminder offset is configured during pact creation. Stretch goal: actionable notifications on iOS and Android so the user can mark a showup as done without opening the app. Coordinate with lazy showup generation. (Feature)
- [HAB-21](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-21/auto-fail-past-due-showups-on-dashboard-load) **Auto-fail past-due showups on dashboard load** — When the dashboard loads or refreshes, any showup whose scheduled window has passed (`now > scheduledAt + duration`) and is still `pending` should be automatically transitioned to `failed` and persisted. (Feature — blocked by HAB-13)

---

## Unscheduled

### Issues

- [HAB-46](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-46/define-habit-loop-technical-stack-before-hab-11) **Define Habit Loop technical stack before HAB-11** — Explicit decisions on the supporting stack in three areas: developer and production diagnostics / logging, local persistence with a strong performance focus, and experimentation tooling and experiment tracking workflow. (Tech Debt)
- [HAB-48](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-48/choose-persistence-layer-for-hab-11-with-performance-as-the-primary) **Choose persistence layer for HAB-11 with performance as the primary constraint** — Evaluate persistence options (sqflite, Drift, Isar, Hive) against transactional correctness, query clarity, isolate/concurrency story, migration safety, and runtime performance before implementing HAB-11. (Tech Debt)

### Remaining work

- [HAB-40](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-40/in-app-language-selection-without-leaving-the-app) **In-app language selection without leaving the app** — Add an in-app language selector so any user can switch between English, French, and German without going to system Settings. (Feature)
