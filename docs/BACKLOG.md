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

- [HAB-22](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-22/auto-refresh-dashboard-when-date-changes-at-midnight) **Auto-refresh dashboard when date changes at midnight** — `nowProvider` is evaluated once and not invalidated while the app stays open; after midnight the calendar strip still shows the previous day as "today" and new showups are not generated until relaunch. On foreground resume, invalidate `nowProvider` if the date has changed; stretch goal: midnight background trigger using the notification infrastructure from HAB-13. (Tech Debt / Feature)

### Remaining work

- [HAB-21](https://linear.app/iurii-lutsenkos-workspace/issue/HAB-21/auto-fail-past-due-showups-on-dashboard-load) **Auto-fail past-due showups on dashboard load** — When the dashboard loads or refreshes, any showup whose scheduled window has passed (`now > scheduledAt + duration`) and is still `pending` should be automatically transitioned to `failed` and persisted. (Feature)

---

## Unscheduled

_(no unscheduled items)_
