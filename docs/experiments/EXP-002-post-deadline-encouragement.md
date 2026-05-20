# EXP-002 — Post-deadline notification behavior (Android only)

## Hypothesis
_We believe that showing an encouraging replacement notification after a missed showup deadline will cause a higher rate of next-showup completion for Android users who have missed at least one showup, because an encouraging nudge reduces discouragement and keeps users engaged with their pact._

## Status
`running`

<!-- Keep only one status. Valid transitions: running → won | lost | abandoned -->

## Setup
| Field | Value |
|---|---|
| Start date | |
| End date | |
| Audience | Android users with at least one active pact with a reminder offset configured, who have at least one missed (auto-failed or pending past-deadline) showup |
| Remote Config flag | `post_deadline_notification_behavior` (values: `dismiss` = control, `encourage` = variant) |
| Ramp plan | 50/50 split from launch |
| Stop rule | Min 6 weeks after 1.0.0 release AND min 150 missed-showup events per group |

### Groups

**Control (`dismiss`):** Original notification is auto-dismissed via `timeoutAfter` at `scheduledAt + duration`. No further notification is shown.

**Encouraging (`encourage`):** At `scheduledAt + duration`, a replacement notification is scheduled (same notification ID) replacing the original in the notification tray with an encouraging message and no action buttons. Example copy: "You missed this one — that's okay. Show up next time."

### Platform scope

Android only. iOS cannot auto-dismiss notifications programmatically, so iOS always shows the encouraging replacement notification by default — iOS users are excluded from this experiment. Android-only targeting is configured in the Firebase A/B Testing console.

### Conflict check

Single-layer experiment. Does not conflict with EXP-001, which controls notification text content before the deadline; EXP-002 controls post-deadline behavior only.

## Metrics
| Metric | Role | Baseline | Result |
|---|---|---|---|
| Rate of next scheduled showup resolved (done or failed) within its showup window, for users who missed at least one showup | Primary | | |
| Pact stop rate (`pact_stopped` events per active pact per week) | Guardrail | | |

## Decision
_What was decided, why, and on what date._

## Learnings
_What this tells us beyond the primary metric._
