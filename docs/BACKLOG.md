# Backlog

Known issues and planned work that has not yet been released.
This file is generated from Linear — do not edit by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).

---

## In QA

- **HAB-104**: Debug menu consolidated — test notification moved from dashboard, section order established (PR #137)
- **HAB-98**: Flutter UI audit — deduplicate platform-specific code into `generic/` (PR #136)
- **HAB-100**: Bug: notifications fire after a pact is stopped — deterministic FNV-1a hash, layer violation fix, hex literal consistency (PR #121)

## Unscheduled

### Issues

_(none)_

### Remaining work

- **HAB-95**: Code's deep and wide audit (epic) — systematic review and cleanup of every project component
  - **HAB-97**: Flutter codebase general audit — dead code, layer adherence, dependency direction, self-documenting code
  - **HAB-99**: Tests audit — coverage and quality review (unit + integration)
- **HAB-101**: Create a generalized skill_router package as a standalone repo — extract skill routing into a reusable, project-agnostic Python package
- **HAB-102**: Update yuriys-agentic-boyz with skill_router improvements from HAB-91/HAB-93/HAB-94
