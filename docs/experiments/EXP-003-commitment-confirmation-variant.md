# EXP-003 — Commitment confirmation variant

## Hypothesis
_We believe that requiring users to actively confirm their commitment during pact creation (checkbox or re-typing the habit name) will result in higher showup completion rates compared to a single button tap, because a more deliberate confirmation creates stronger psychological ownership over the habit. We further believe the re-type variant will outperform the checkbox variant for the same reason._

## Status
`running`

<!-- Keep only one status. Valid transitions: running → won | lost | abandoned -->

## Setup
| Field | Value |
|---|---|
| Start date | Ships with HAB-82 |
| End date | 8 weeks after 1.0.0 release |
| Audience | All users who create a pact (3-way equal split) |
| Remote Config flag | `exp_003_commitment_confirmation` (values: `button` = control, `checkbox` = variant_a, `retype` = variant_b) |
| Ramp plan | 10% of sessions first (instrumentation check) → 33/33/33% equal split → 100% or kill |
| Stop rule | Min 300 pact creations per variant OR 8 weeks after 1.0.0 release, whichever comes first; stop early if guardrail drops > 15% relative in any variant |

### Groups

**Control (`button`):** A dialog appears when the user taps Create on the summary screen, showing the commitment rules ("missing a showup counts as a failure, no exceptions — no pausing") and a single "I accept" button. No checkbox, no text entry.

**Variant A (`checkbox`):** The same dialog with a checkbox labelled "I have read and accept the commitment rules" that must be ticked before the "Create pact" action button is enabled.

**Variant B (`retype`):** The same dialog asks the user to type their habit name in a text field to confirm. The "Create pact" button is enabled only when the typed text matches the habit name (case-insensitive, trimmed).

### Conflict check
Single-layer experiment on the pact creation flow. Does not conflict with EXP-001 or EXP-002, which control notification behaviour after pact creation.

## Metrics
| Metric | Role | Baseline | Result |
|---|---|---|---|
| Showup completion rate — showups marked done / showups expected per pact, averaged over the first 30 active days | Primary | unknown | |
| Pact creation completion rate — users who open the confirmation dialog and successfully create the pact (`pact_created` events / dialog opens) | Guardrail | unknown | |

## Analytics events needed
- `pact_created` gains new property `commitment_variant: string` (`button` \| `checkbox` \| `retype`) — required to group primary metric by variant
- New event `pact_commitment_dialog_dismissed` with property `variant: string` — tracks guardrail abandonment at the dialog level
- Both require a `docs/ANALYTICS_EVENTS.md` update (via `analyze` skill) before implementation

## Decision
_What was decided, why, and on what date._

## Learnings
_What this tells us beyond the primary metric._
