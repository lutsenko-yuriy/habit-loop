# EXP-001 — Notification text urgency

## Hypothesis
_We believe that urgency-framing in notification text will cause higher rates of showups being marked done or failed for users with active pacts and a reminder offset configured, because a concrete time deadline makes the cost of inaction salient and prompts immediate action._

## Status
`abandoned`

<!-- Keep only one status. Valid transitions: pending → running → won | lost | abandoned -->

## Setup
| Field | Value |
|---|---|
| Start date | Ships with v0.20.0 (HAB-13) |
| End date | At least 4 weeks after 1.0.0 release |
| Audience | All users with at least one active pact that has a reminder offset configured |
| Remote Config flag | `notification_text_variant` (`control` \| `deadline` \| `time_limit`) |
| Ramp plan | Equal three-way split (33% / 33% / 33%) from launch |
| Stop rule | Min 4 weeks after 1.0.0 release, min 200 showup-notification impressions per group |

### Variants

| Variant | Remote Config value | Example text |
|---|---|---|
| Control | `control` | "Time to {habit name}" |
| Deadline | `deadline` | "Mark your {habit name} showup done by {time}" |
| Time-limit | `time_limit` | "You have {X} hours/minutes to mark your {habit name} showup" |

**Platform note:** Android supports native notification auto-dismiss (`timeoutAfter`) so the deadline messaging is authentically reinforced; iOS does not support auto-dismiss so notifications linger past the deadline. Results must be stratified by platform when analysing.

## Metrics
| Metric | Role | Baseline | Result |
|---|---|---|---|
| (`showup_marked_done` + `showup_marked_done_from_notification`) rate per scheduled showup within the showup window | Primary | | |
| `showup_auto_failed` rate per scheduled showup | Guardrail | | |

## Decision
Abandoned, 2026-08-31, during HAB-232 WU7. The `deadline`/`time_limit` variants shipped with v0.20.0
but the `notification_text_variant` Remote Config rollout was never actually flipped away from
`control` — the experiment sat `pending` through dozens of subsequent releases. Discovered and killed
while adding display-name personalization to notification titles (HAB-232): personalizing three
divergent title templates (control/deadline/time_limit) for a dormant, never-launched experiment wasn't
worth the added surface, and the variant copy itself had gone stale/awkward in review. Removed the
variant dispatch from `NotificationTextBuilder`, `ReminderPlanContext`, and the
`notification_text_variant` Remote Config key entirely rather than carry dead code forward.

## Learnings
Ship the actual ramp (flip the RC value away from its dormant default) close to when the experiment
code lands — a `pending` experiment with no forcing function to launch it just accumulates as
maintenance weight on every unrelated change to the same code path, until someone removes it years
later having gotten zero data from it.
