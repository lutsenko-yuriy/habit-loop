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

Fired when a showup is automatically transitioned to failed because its scheduled window has passed (`now > scheduledAt + duration`). This event covers two triggers:

- **Dashboard load/refresh sweep** — `DashboardViewModel.load()` sweeps all past-due pending showups in the visible strip window (up to 3 days before today through today) and auto-fails each one.
- **Showup detail screen open** — `ShowupDetailViewModel.load()` auto-fails the specific showup being viewed if its window has elapsed.

Both triggers use the same `ShowupAutoFailedEvent` class. No additional properties distinguish the trigger source, since the downstream action (showup is now failed) is identical in both cases.

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

### `app_opened_from_notification`

Fired when the app is opened (cold-started or resumed from background) because the user tapped a reminder notification. This is the deep-link routing event and fires from the navigation layer using data already present in the notification payload — no DB round-trip is needed. It is distinct from the planned `notification_opened` event (which will include `minutes_before_showup` but requires a showup DB lookup and is tracked separately).

Event class: `AppOpenedFromNotificationEvent` in `lib/slices/reminder/analytics/reminder_analytics_events.dart`

| Property | Type | Description |
|---|---|---|
| `pact_id` | `string` | ID of the parent pact from the notification payload |
| `showup_id` | `string` | ID of the showup from the notification payload |
| `cold_start` | `bool` | `true` if the app was launched from a killed state; `false` if resumed from background |

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

### `sync_status_opened`

Fired when the user taps the sync icon in the dashboard nav bar and the sync status dialog opens. (HAB-64)

| Property | Type | Description |
|---|---|---|
| `state` | `string` | Current sync state: `not_linked` \| `connecting` \| `synced` \| `degraded` \| `suspended` \| `no_internet` |

---

### `manual_sync_triggered`

Fired when the user taps "Sync now" inside the sync status dialog. (HAB-64)

| Property | Type | Description |
|---|---|---|
| `from_state` | `string` | CB state that prompted the action: `degraded` \| `suspended` |

---

### `sign_in_with_google_tapped`

Fired when the user taps "Sign in with Google" inside the sync status dialog (shown when auth state is anonymous / not linked). (HAB-64)

No properties — context is captured by `sync_status_opened` with `state=not_linked`.

---

### `sign_in_with_google_succeeded`

Fired when Google account linking completes successfully. (HAB-64)

No properties.

---

### `sign_in_with_google_failed`

Fired when Google account linking throws a `FirebaseAuthException`. (HAB-64)

| Property | Type | Description |
|---|---|---|
| `error_code` | `string` | Firebase error code (e.g. `account-exists-with-different-credential`) — not PII |

---

### `sign_out_tapped`

Fired when the user taps "Sign out" inside the sync status dialog. (HAB-64)

| Property | Type | Description |
|---|---|---|
| `from_state` | `string` | Sync state at the time of sign-out |

---

### `full_sync_triggered`

Fired when the user taps "Full sync" in the sync status dialog. The button is visible only in `synced`, `degraded`, and `suspended` states (online + logged in). (HAB-69)

| Property | Type | Description |
|---|---|---|
| `from_state` | `string` | Sync state when the button was tapped: `synced` \| `degraded` \| `suspended` |

---

### `full_sync_completed`

Fired when a user-triggered full sync finishes with zero record failures. (HAB-69)

| Property | Type | Description |
|---|---|---|
| `from_state` | `string` | Sync state when the sync was triggered |

---

### `full_sync_failed`

Fired when a user-triggered full sync finishes with at least one record that failed to upload. (HAB-69)

| Property | Type | Description |
|---|---|---|
| `from_state` | `string` | Sync state when the sync was triggered |
| `records_failed` | `int` | Number of records that failed to upload |

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
