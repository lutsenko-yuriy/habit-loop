# Backlog

Known issues and planned work that has not yet been released.
This file is generated from Linear — do not edit by hand. Source of truth: [Habit Loop project on Linear](https://linear.app/iurii-lutsenkos-workspace/project/habit-loop-flutter-app-created-with-assistance-of-claude-bf8b51a86175).

---

## In QA

- **HAB-100**: Bug: notifications fire after a pact is stopped — deterministic FNV-1a hash, layer violation fix, hex literal consistency (PR #121)
- **HAB-90**: Debug mode config overrides — emulate connection issues (FakeFirestoreClient, FaultInjectingFirestoreClient, debug wiring)

## In Review

- **HAB-92**: Port LM Studio routing system to yuriys-agentic-boyz — copy script + stubs after HAB-91 WU2 is merged and tested

## Unscheduled

### Issues

_(none)_

### Remaining work

- **HAB-95**: Code's deep and wide audit (epic) — systematic review and cleanup of every project component
  - **HAB-97**: Flutter codebase general audit — dead code, layer adherence, dependency direction
  - **HAB-98**: Flutter UI audit — deduplicate platform-specific code into `generic/`
  - **HAB-99**: Tests audit — coverage and quality review (unit + integration)
