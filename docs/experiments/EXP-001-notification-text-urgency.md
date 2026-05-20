# EXP-001 — Notification text urgency

## Hypothesis
_We believe that urgency-framing in notification text will cause higher rates of showups being marked done or failed for users with active pacts and a reminder offset configured, because a concrete time deadline makes the cost of inaction salient and prompts immediate action._

## Status
`pending`

<!-- Keep only one status. Valid transitions: pending → running → won | lost | abandoned -->

## Setup
| Field | Value |
|---|---|
| Start date | Ships with HAB-13 |
| End date | At least 4 weeks after rollout |
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
_What was decided, why, and on what date._

## Learnings
_What this tells us beyond the primary metric._
