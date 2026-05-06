# Analytics Events

All events are sent via `AnalyticsService` (a thin Riverpod-provided wrapper around `FirebaseAnalytics`).

---

## Events

### `pact_created`

Fired when the user successfully completes the pact creation wizard and the pact is persisted.

| Property | Type | Description |
|---|---|---|
| `schedule_type` | `string` | `daily` \| `weekly` \| `monthly` |
| `duration_days` | `int` | Pact length in calendar days, inclusive of both start and end dates |
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

### `language_change_requested`

Fired when the user opens the language picker (before any selection is made). Lets us measure how often users explore language switching without completing the change.

| Property | Type | Description |
|---|---|---|
| `source` | `string` | Where the picker was triggered from; currently always `dashboard` |

---

### `language_changed`

Fired when the user selects a different language and the change is applied.

| Property | Type | Description |
|---|---|---|
| `from_language` | `string` | Language active before the change: `en` \| `fr` \| `de` \| `ru` |
| `to_language` | `string` | Language selected by the user: `en` \| `fr` \| `de` \| `ru` |
| `source` | `string` | Where the picker was triggered from; currently always `dashboard` |

No PII risk — values are ISO 639-1 language codes drawn from a closed set.

---

## Screen Views

Tracked via `AnalyticsService.logScreenView(screen)`, which calls `FirebaseAnalytics.logScreenView`.

`AnalyticsScreen` is an abstract class (not an enum). Each vertical's `analytics/` subdirectory provides its own concrete implementations:

| Concrete class | `screen_name` | Source file | When |
|---|---|---|---|
| `DashboardAnalyticsScreen` | `dashboard` | `slices/dashboard/analytics/dashboard_screens.dart` | Dashboard screen opens or becomes visible again after returning from a detail/creation flow |
| `LanguagePickerAnalyticsScreen` | `language_picker` | `slices/dashboard/analytics/language_analytics_events.dart` | Language picker sheet/dialog opens (iOS: `CupertinoActionSheet`; Android: `SimpleDialog`) |
| `PactCreationAnalyticsScreen` | `pact_creation` | `slices/pact/analytics/pact_analytics_events.dart` | Pact creation wizard opens |
| `PactDetailAnalyticsScreen` | `pact_detail` | `slices/pact/analytics/pact_analytics_events.dart` | Pact detail screen opens |
| `ShowupDetailAnalyticsScreen` | `showup_detail` | `slices/showup/analytics/showup_analytics_events.dart` | Showup detail screen opens |
