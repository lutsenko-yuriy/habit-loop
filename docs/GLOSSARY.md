# Glossary

The **ubiquitous language** (Eric Evans, *Domain-Driven Design*) for Habit Loop: one canonical term per concept, shared by code, UI copy, analytics, and docs.

When you find a different word used for the same concept, look it up in **[Known term drift](#known-term-drift)** at the bottom — it maps each alias back to the canonical term. Keep this file in sync whenever the domain vocabulary changes.

---

## Core concepts

| Term | Definition | Code symbol |
|---|---|---|
| **Pact** | The central commitment. A user pledges to show up for one habit over a fixed time span; missing a showup is a failure, with no pausing. | `Pact` (`lib/domain/pact/`) |
| **Showup** | A single scheduled occurrence of the habit within a pact (e.g. "meditate at 08:00 on Tuesday"). The unit the user marks done or failed. | `Showup` (`lib/domain/showup/`) |
| **Habit** | The activity the user wants to build (meditate, jog…). Not a separate entity — stored as the `habitName` string on the pact. | `Pact.habitName` |
| **Schedule** | The recurrence rule that determines when a pact's showups fall. | `ShowupSchedule` |
| **Slot** | One row of a card-based schedule: a set of weekdays *or* a day-of-month, plus a single time. The current schedule UX is built from slots. | `ScheduleSlot` → `WeeklySlot`, `MonthlySlot` |
| **Showup window** | The interval `[scheduledAt, scheduledAt + showupDuration]` during which a showup is open and can be marked done. Once it closes, an unresolved showup auto-fails. | derived from `Showup.scheduledAt` + `duration` |
| **Showup duration** | Length of a single showup session (e.g. 10 min; max 2 h). | `Pact.showupDuration`, `Showup.duration` |
| **Reminder offset** | How long before `scheduledAt` the reminder notification fires. `null` = no reminder; up to 60 min before. `reminderFiresAt = scheduledAt − reminderOffset`. | `Pact.reminderOffset` |
| **Streak** | The current run of consecutive **done** showups, counting back from the most recent resolved showup. Pending showups don't break or extend it. | `PactStats.currentStreak` |
| **Stats** | Computed per-pact totals: done, failed, remaining, total, current streak. Never persisted as truth — derived from showups (with a session cache). | `PactStats` |

---

## States

| Concept | Values | Notes |
|---|---|---|
| **Pact status** | `active` · `stopped` · `completed` | `stopped` = user ended it early; `completed` = reached end date or all showups resolved. | 
| **Showup status** | `pending` · `done` · `failed` | The persisted domain truth. `failed` covers both manual marking and auto-fail. |
| **Showup UI state** | `planned` · `waitingForStart` · `active` · `done` · `failed` | **UI-layer only** — derived from `now`, `scheduledAt`, `duration`, and `reminderOffset`. Not a domain model. Used for calendar dots and the detail status chip. |

---

## Lifecycle & behaviours

| Term | Definition |
|---|---|
| **Auto-fail** | Automatic transition of a `pending` showup to `failed` once its window has passed. Triggers: dashboard load sweep, opening showup detail late, and gap-fill. |
| **Gap-fill** | When the app is reopened after a long absence, the showups that fell in the gap are generated and immediately auto-failed so history and stats stay accurate. |
| **Stop (a pact)** | The user ends an active pact early, with explicit confirmation and an optional explanation (the *stop reason*). Records `stoppedAt`. Distinct from *complete*. |
| **Archive (a pact)** | The user tucks a completed or stopped pact into long-term storage, removing it from the default pact list without deleting it. A display-only flag — no effect on stats, reminders, or sync logic. Only completed and stopped pacts are eligible. |
| **Unarchive (a pact)** | The user brings an archived pact back into the default list view, making it visible again without requiring the Archived filter. The pact's history and stats are unchanged throughout. |
| **Showup generation** | Deterministic creation of showups from a pact's schedule. Generated lazily in a rolling **generation window** ahead of today, not all upfront. |
| **Commitment confirmation** | The gate shown before a pact is created, making the "no exceptions, no pausing" commitment explicit. Variant under EXP-003 (`button` / `checkbox` / `retype`). |
| **Redeem (a showup)** | Marking an auto-failed (not manually failed) showup as done, by writing a required note. Only available within the tail zone (last N days, `pact_timeline_no_grouping_tail_period_in_days`). Gated by `showup_redemption_enabled`. |
| **Milestone** | One grouped unit shown on the pact timeline: a streak run, a mixed group, a single or noted showup, or an anchor (pact created / current state / concluded). Distinct from an analytics event or a generic UI list item (`PactTimelineMilestone`, `slices/pact/application/`). |

---

## Sync & infrastructure

| Term | Definition |
|---|---|
| **Dirty** | A local SQLite record with unsynced changes (`dirty = 1`, `synced_at = null`). Every local write marks the row dirty for the next sync pass. |
| **Circuit breaker** | Guards all Firestore requests. States: `closed` (flowing) · `halfOpen` (probing after a failure) · `open` (suspended). In-memory only; resets to `closed` on restart. |
| **Write-through** | Sync model: after every successful local write, the record is uploaded fire-and-forget. Sync never blocks the local path. |
| **Pull** | On app start, remote pacts/showups are fetched and merged into local SQLite via **last-writer-wins** (`pullRemoteChanges`). |
| **Device ID** | A stable per-install UUID that prefixes new pact IDs (`{deviceId}-{uuid}`) so IDs never collide across a user's devices. |

---

## UI surfaces

| Term | Definition |
|---|---|
| **Dashboard** | The home screen: calendar strip + showup list for the selected day + pacts panel. |
| **Calendar strip** | The 7-day band (today ±3) with coloured dots per showup (green = done, red = failed, grey/amber = upcoming). |
| **Pacts panel** | The draggable sheet listing all pacts with Active / Done / Stopped filter chips. |
| **Onboarding carousel** | The four-slide intro shown only to users with zero pacts. |
| **Pact timeline** | The full-history milestone view of a pact's showups, reached via "View timeline" on pact detail. Loaded and grouped in one pass — no pagination. Gated by `pact_timeline_enabled`. |

---

## Known term drift

These aliases appear in code, UI copy, analytics, or older docs. Prefer the **canonical** term in new work; when you must touch the alias (e.g. an l10n key), leave the meaning intact but don't spread it further.

| Alias / variant | Canonical | Where the alias lives | Note |
|---|---|---|---|
| session, check-in | **showup** | — | Use *showup* everywhere. |
| commitment | **pact** | EXP-003 "commitment confirmation" | The pact *embodies* a commitment; the confirmation dialog is correctly named, but the entity is a *pact*. |
| made, "made it to" | **done** | `docs/PRODUCT_SPEC.md` prose | The status and stat field are `done` / `showupsDone`. |
| cancelled | **stopped** | l10n `filterCancelled`, `pactsCancelled`, `pactCancelledOn` | Domain status is `stopped`. UI still labels it "Cancelled" — a known mismatch; don't rename strings without a deliberate copy pass. |
| weekday (schedule) | **weekly** | legacy class `WeekdaySchedule` / `WeekdayEntry` | The new card UX (`WeeklySlot`), `ScheduleType.weekly`, and the `schedule_type` analytics value all say *weekly*. Legacy `WeekdaySchedule` predates the rename and still loads for old pacts. |
| session length | **showup duration** | — | `showupDuration` / `Showup.duration`. |
| notification | **reminder** | `flutter_local_notifications`, `NotificationService` | *Reminder* is the user-facing concept; *notification* is the platform delivery mechanism. Both are correct in their layer. |
| todo list | **showup list** | `docs/PRODUCT_SPEC.md` ("todo list of showups") | The dashboard's per-day list of showups. |
| showups expected | **total showups** | `showups_expected` analytics property | Same value as `PactStats.totalShowups`. |

---

## Per-language canonical terms

Canonical translation for each domain concept across all supported locales. Consult this table before writing or reviewing any l10n string.

| Concept | Russian | French | German |
|---|---|---|---|
| **showup** | явка | séance | Showup |
| **pact** | пакт | pacte | Pakt |
| **habit** | привычка | habitude | Gewohnheit |
| **streak** | Серия | Série | Serie |
| **done** (showup status) | Выполнено | Réalisé | Erledigt |
| **failed** (showup status) | Пропущено | Échoué | Verpasst |
| **stopped** (pact status) | Остановлен | Arrêté | Gestoppt |
| **completed** (pact status) | Завершён | Terminé | Abgeschlossen |
| **timeline** | Хронология | Chronologie | Verlauf |
| **schedule** | Расписание | Horaire | Zeitplan |
| **reminder** | Напоминание | Rappel | Erinnerung |
| **archive** | Архив | Archivage | Archiv |
