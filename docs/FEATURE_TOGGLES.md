# Feature Toggles

Boolean Firebase Remote Config flags that enable/disable features without a release. All default to `true` (current behaviour preserved). Flags are readable on the in-app RC overrides screen (debug/profile only).

`Review by` is assigned/verified during the `/checkup` light-tier feature-flag-lifecycle pass — a flag past its review date is a candidate for either removal (feature graduated to permanent) or a fresh review date, not an automatic deadline for action.

| Flag | Default | Effect when `false` | Review by |
|---|---|---|---|
| `language_selection_enabled` | `true` | Language-picker button hidden from dashboard and onboarding carousel; locale preference unchanged, replays on re-enable | 2027-01-16 |
| `network_sync_enabled` | `true` | All `FirestoreSyncService` methods no-op; sync status button and Sign in with Google hidden; local writes persisted as dirty and uploaded on re-enable | 2027-01-16 |
| `pact_timeline_enabled` | `true` | "View timeline" button hidden from pact detail screens; timeline route unreachable; no data is cleared | 2026-11-16 |
| `showup_redemption_enabled` | `true` | Redemption button hidden on showup detail screen; auto-failed tail-zone showups cannot be redeemed; `redeemable` flag on showup records is unaffected | 2026-11-16 |
| `about_screen_enabled` | `true` | About icon button hidden from the dashboard nav bar; the About screen is unreachable | 2026-11-16 |
