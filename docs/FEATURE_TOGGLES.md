# Feature Toggles

Boolean Firebase Remote Config flags that enable/disable features without a release. All default to `true` (current behaviour preserved). Flags are readable on the in-app RC overrides screen (debug/profile only).

| Flag | Default | Effect when `false` |
|---|---|---|
| `language_selection_enabled` | `true` | Language-picker button hidden from the dashboard; locale preference unchanged, replays on re-enable |
| `network_sync_enabled` | `true` | All `FirestoreSyncService` methods no-op; sync status button hidden from dashboard; local writes persisted as dirty and uploaded on re-enable |
