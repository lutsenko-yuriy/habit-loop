# Experiment Registry

All product experiments are tracked here. One file per experiment under this directory.

## Stack
- **Running experiments:** Firebase Remote Config + Firebase A/B Testing (A/B Testing is a Firebase Console feature layered on top of Remote Config — no additional Dart SDK or `pubspec.yaml` entry required beyond `firebase_remote_config`)
- **Tracking outcomes:** This registry (one `.md` file per experiment)
- **When to revisit dedicated tooling** (Statsig, LaunchDarkly, PostHog): when running >5 concurrent experiments or needing richer governance/analysis

## Starting an experiment

1. Pick the next sequential `EXP-NNN` ID from the index table below.
2. Copy `docs/experiments/TEMPLATE.md` to `docs/experiments/EXP-NNN-<short-name>.md`.
3. Fill in the hypothesis, setup, and metrics sections. Leave Decision and Learnings blank.
4. Add a row to the Index table with status `pending`.
5. When the experiment goes live, update the status to `running` and fill in the Start date.

## Statuses

| Status | Meaning |
|---|---|
| `pending` | Experiment is designed and code is merged, but not yet live (ramp not started) |
| `running` | Experiment is live and collecting data |
| `won` | Hypothesis confirmed — change shipped to 100% |
| `lost` | Hypothesis rejected — variant rolled back |
| `abandoned` | Stopped early (low traffic, flawed setup, changed priorities) — no conclusive result |

## Index

| ID | Name | Status | Start date | End date | Primary metric result | Decision date |
|---|---|---|---|---|---|---|
| EXP-001 | notification-text-urgency | `running` | with v0.20.0 | 4 wks after 1.0.0 | | |
| EXP-002 | post-deadline-encouragement | `running` | with v0.20.0 | 6 wks after 1.0.0 | | |
| EXP-003 | commitment-confirmation-variant | `pending` | with HAB-82 | 8 wks after 1.0.0 | | |
