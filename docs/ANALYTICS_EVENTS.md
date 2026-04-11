# Analytics Events

All events are sent via `AnalyticsService` (a thin Riverpod-provided wrapper around `FirebaseAnalytics`).

> **GDPR note:** `pact_name` in `pact_created` is user-entered text. Ensure your privacy policy discloses that habit names are transmitted to Firebase Analytics.

---

## Events

### `pact_created`

Fired when the user successfully completes the pact creation wizard and the pact is persisted.

| Property | Type | Description |
|---|---|---|
| `schedule_type` | `string` | `daily` \| `weekly` \| `monthly` |
| `duration_days` | `int` | Pact length in days |
| `showup_duration_minutes` | `int` | Length of a single showup in minutes |
| `reminder_offset_minutes` | `int?` | Minutes before showup for reminder; `null` if no reminder set |
| `showups_expected` | `int` | Total number of showups scheduled over the full pact |

---

### `showup_marked_done`

Fired when the user manually marks a showup as done from the showup detail screen.

| Property | Type | Description |
|---|---|---|
| `pact_id` | `string` | ID of the parent pact (join with `pact_created` for habit name) |

---

### `showup_marked_failed`

Fired when the user manually marks a showup as failed from the showup detail screen. Auto-fail is tracked separately.

| Property | Type | Description |
|---|---|---|
| `pact_id` | `string` | ID of the parent pact (join with `pact_created` for habit name) |

---

### `showup_auto_failed`

Fired when a showup is automatically transitioned to failed because the showup detail screen was opened after the scheduled window has passed (`now > scheduledAt + duration`).

| Property | Type | Description |
|---|---|---|
| `pact_id` | `string` | ID of the parent pact (join with `pact_created` for habit name) |

---

### `pact_stopped`

Fired when the user confirms stopping an active pact.

| Property | Type | Description |
|---|---|---|
| `days_active` | `int` | Number of days from pact start to the stop date |
| `total_showups_done` | `int` | Showups marked done at the time of stopping |
| `total_showups_failed` | `int` | Showups marked failed at the time of stopping |
| `total_showups_remaining` | `int` | Showups still pending at the time of stopping |

---

## Screen Views

Tracked via `AnalyticsService.logScreenView(screenName)`, which calls `FirebaseAnalytics.logScreenView`.

| `screen_name` | When |
|---|---|
| `dashboard` | Dashboard screen opens |
| `pact_creation` | Pact creation wizard opens |
| `pact_detail` | Pact detail screen opens |
| `showup_detail` | Showup detail screen opens |
