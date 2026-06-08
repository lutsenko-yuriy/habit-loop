---
name: analyze
effort: FOCUSED
reasoning: ARCHITECTURAL
output_style: DETAILED
description: Analytics planning for a feature before implementation begins. Identifies the user-facing actions and screens introduced by a task, proposes which events and screen views to track, flags PII concerns, and updates docs/ANALYTICS_EVENTS.md after approval. Invoke for any feature or change with user-visible screens or interactions, before `plan` or `implement`.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

This skill produces an analytics plan, not code.

---

## Steps

### 1. Fetch the issue

Call `mcp__linear__get_issue` to retrieve the full details of the issue (title, description, acceptance criteria, mockups or flow descriptions).

### 2. Read the existing analytics catalogue

Read `docs/ANALYTICS_EVENTS.md` in full to understand what is already tracked and avoid proposing duplicates.

### 3. Read the product context

Read `docs/PRODUCT_SPEC.md` and any relevant source files to understand the user journey this feature sits within. Look for existing screen names, navigation patterns, and event naming conventions already used in the codebase.

### 4. Identify trackable moments

Walk through the feature from the user's perspective and identify:

- **Screen views** — every distinct screen or modal the user lands on
- **Actions** — every deliberate user action (taps, submissions, selections, dismissals)
- **Outcomes** — results that matter for product understanding (success, failure, abandonment)
- **Transitions** — navigating between states where understanding drop-off is valuable

For each moment, ask: *Would a product or growth team make a decision based on this data?* If no, omit it.

### 5. Flag PII risks

For each proposed event and property, assess:
- Does the value identify a specific user or reveal sensitive behaviour?
- Is it safe to send to a third-party analytics service (Firebase Analytics)?

Mark any property carrying PII risk with `⚠️ PII` and propose a safe alternative (e.g. hash, bucketed value, or omission).

**PII rule for this project:** never include user-entered text (habit names, notes, stop reasons) as event properties — only field lengths, IDs, counts, and enum values.

### 6. Propose the analytics plan

Present the proposal in this format. Omit a section if empty.

@skills/design/analyze/resources/analytics-plan-template.md

Follow the naming conventions in `docs/ANALYTICS_EVENTS.md`: `snake_case` for event names. Event classes live in `slices/<vertical>/analytics/`, extend `AnalyticsEvent`, and are passed to `AnalyticsService.logEvent()`. Screen view classes extend `AnalyticsScreen`.

### 7. Wait for approval

Present the plan and ask:

> "Does this analytics plan look right? Confirm or adjust before I update the catalogue."

Do not proceed until the user explicitly approves or provides corrections.

### 8. Update the analytics catalogue

Open `docs/ANALYTICS_EVENTS.md` and append the approved entries to the appropriate sections (Events, Screen Views). Include the issue reference so the origin is traceable.

Do not modify existing entries — only append.

### 9. Report back

Confirm what was added to `docs/ANALYTICS_EVENTS.md`. Remind the orchestrator that `implement` should include the instrumentation calls defined here.
