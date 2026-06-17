---
name: validate
effort: FOCUSED
reasoning: TACTICAL
context: linear
output_style: CONCISE
description: Generate integration tests from a ticket description before implementation. Runs after `plan` (if used) and before `implement`. Tests are written against the spec — not reverse-engineered from code — so they start red and give `implement` a clear target.
---

The project management tool is **Linear**. The issue identifier prefix is **HAB**.

This skill produces test files, not production code.

---

## Steps

### 1. Fetch the ticket

Call `mcp__linear__get_issue` on the issue. Then call `mcp__linear__list_comments` to find any plan comment left by the `plan` skill. Read the description, acceptance criteria, and plan (if present) to understand the expected behaviour.

### 2. Read the test harness

Read `integration_test/harness.dart` and any existing integration tests in `integration_test/` for the affected slice or feature area. Note naming conventions, helper patterns, and what is already covered so you do not duplicate.

### 3. Draft integration tests

Produce draft test files in `integration_test/` using `AppHarness`. Cover:

- **Happy path** — the primary flow described in the ticket
- **Unhappy paths** — the most critical failure scenarios: missing data, invalid state, navigation back-stack correctness, cancelled operations, etc.

Write the minimum set of tests that verifies the ticket's acceptance criteria. Do not add speculative coverage.

### 4. Present and wait

Show all proposed test files to the user and wait for approval. Do not write any files to disk until the user approves. Incorporate any requested changes before writing.

### 5. Write the tests

Write the approved test files. The tests must be **red** at this point — no production code exists yet, and that is the intended state. If a test passes without implementation, it is testing nothing; revise it.

### 6. Report back

List the files written and confirm that `implement` can proceed with a clear red-green target.

---

## Constraints

- Do not write production code.
- Tests must be red when written.
- Use `AppHarness` from `integration_test/harness.dart` for all test setup.
- Do not duplicate tests that already cover the same behaviour.
