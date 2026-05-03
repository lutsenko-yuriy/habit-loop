# Experiment Registry

All product experiments are tracked here. One file per experiment under this directory.

## Stack
- **Running experiments:** Firebase Remote Config + Firebase A/B Testing
- **Tracking outcomes:** This registry (one `.md` file per experiment)
- **When to revisit dedicated tooling** (Statsig, LaunchDarkly, PostHog): when running >5 concurrent experiments or needing richer governance/analysis

## Statuses

| Status | Meaning |
|---|---|
| `running` | Experiment is live and collecting data |
| `won` | Hypothesis confirmed — change shipped to 100% |
| `lost` | Hypothesis rejected — variant rolled back |
| `abandoned` | Stopped early (low traffic, flawed setup, changed priorities) — no conclusive result |

## Index

| ID | Name | Status | Primary metric result | Decision date |
|---|---|---|---|---|
| _(no experiments yet)_ | | | | |
