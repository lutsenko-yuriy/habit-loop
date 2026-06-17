---
name: draft-scenarios
effort: FOCUSED
reasoning: TACTICAL
context: linear
output_style: CONCISE
description: Draft scenarios (integration tests) from a ticket description before implementation. Runs after `plan` (if used) and before `implement`. Scenarios are written against the spec — not reverse-engineered from code — so they start red and give `implement` a clear target.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

This skill produces scenario files, not production code.

**Terminology:** a *scenario* is an end-to-end integration test written in `integration_test/` using `AppHarness`. The terms "scenario" and "integration test" are synonymous in this project.

---

## Steps

### 1. Fetch the ticket

Call `mcp__linear__get_issue` on the issue. Then call `mcp__linear__list_comments` to find any plan comment left by the `plan` skill. Read the description, acceptance criteria, and plan (if present) to understand the expected behaviour.

### 2. Read the test harness

Read `integration_test/harness.dart` and any existing scenarios in `integration_test/` for the affected slice or feature area. Note naming conventions, helper patterns, and what is already covered so you do not duplicate.

### 3. Draft scenarios

Produce draft scenario files in `integration_test/` using `AppHarness`. Cover:

- **Happy path** — the primary flow described in the ticket
- **Unhappy paths** — the most critical failure scenarios: missing data, invalid state, navigation back-stack correctness, cancelled operations, etc.

Write the minimum set of scenarios that verifies the ticket's acceptance criteria. Do not add speculative coverage.

### 4. Present and wait

Show all proposed scenarios to the user and wait for approval. Do not write any files to disk until the user approves. Incorporate any requested changes before writing.

For each scenario present:
1. **Name** — the test name as it will appear in code.
2. **Description** — one sentence on what behaviour it verifies.
3. **Steps** — a numbered list of the interactions and assertions in order (e.g. "1. Seed a stopped pact with an existing note", "2. Open pact detail", "3. Verify note field is pre-populated", "4. Edit the text — Save button becomes enabled", "5. Tap Save — note is persisted in the repository").

This level of detail lets the user verify the test logic before anything is written to disk.

### 5. Write the scenarios

Write the approved scenario files. The scenarios must be **red** at this point — no production code exists yet, and that is the intended state. If a scenario passes without implementation, it is testing nothing; revise it.

### 6. Report back

List the files written and confirm that `implement` can proceed with a clear red-green target.

---

## Constraints

- Do not write production code.
- All scenario files must be written under `integration_test/`.
- Scenarios must be red when written.
- Use `AppHarness` from `integration_test/harness.dart` for all scenario setup.
- Do not duplicate scenarios that already cover the same behaviour.
