# Feature Toggles

Boolean Firebase Remote Config flags that enable/disable features without a release. All default to `true` (current behaviour preserved). Flags are readable on the in-app RC overrides screen (debug/profile only).

| Flag | Default | Effect when `false` |
|---|---|---|
| `language_selection_enabled` | `true` | Language-picker button hidden from dashboard and onboarding carousel; locale preference unchanged, replays on re-enable |
| `network_sync_enabled` | `true` | All `FirestoreSyncService` methods no-op; sync status button and Sign in with Google hidden; local writes persisted as dirty and uploaded on re-enable |
| `pact_timeline_enabled` | `true` | "View timeline" button hidden from pact detail screens; timeline route unreachable; no data is cleared |
| `showup_redemption_enabled` | `true` | Redemption button hidden on showup detail screen; auto-failed tail-zone showups cannot be redeemed; `redeemable` flag on showup records is unaffected |
| `about_screen_enabled` | `true` | About icon button hidden from the dashboard nav bar; the About screen is unreachable |
