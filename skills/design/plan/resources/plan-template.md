```
## Implementation plan — <short title>

### Issues
- HAB-XX: <title>

### New packages / dependencies
- <package>: <why needed>

### New models and classes
- `ClassName` in `lib/slices/<feature>/...` — <one-line purpose>

### Changes to existing classes
- `ClassName` (`lib/path/to/file.dart`): <what changes and why>

### UI changes
**iOS** (`lib/slices/<feature>/ui/ios/`):
- <change>

**Android** (`lib/slices/<feature>/ui/android/`):
- <change>

### Test strategy
- <what to test and how; name the test files>
- **If WU0 is a verification checklist instead of scenarios**, list it here instead of a prose paragraph:
  - [ ] [agent] <dry-run step the agent runs itself>
  - [ ] [human] <check only a person can make>

### Implementation phases
1. **Phase 1 — <name>**: <what gets done; deliverable>
2. **Phase 2 — <name>**: <what gets done; deliverable>

### Work units
WU0 is always the first unit. When the ticket has a user-facing flow `draft-scenarios` can assert against, WU0 is integration scenarios (no production code) — give it a table row, as below. When it doesn't, WU0 is the verification checklist in Test strategy above instead — it has no branch, PR, or LoC of its own, so **omit its table row entirely**; the table below starts at WU1 in that case. Subsequent WUs should target ≤ 300 LoC changed and ≤ 10 files; split further if a WU would exceed these. Each WU lists which scenarios it makes green.

| # | Unit | Branch | Issues | Scenarios made green | Analytics events fired | Est. LoC | Files touched (approx) |
|---|------|--------|--------|----------------------|-----------------------|----------|------------------------|
| 0 | Integration scenarios (`draft-scenarios` output) — omit this row if WU0 is a checklist instead | `feature/HAB-XX-WU0-scenarios` | HAB-XX | — (stubs; filled in per WU) | — | ~50 | `integration_test/...` |
| 1 | <unit name> | `feature/HAB-XX-WU1-<short>` | HAB-XX | S1, S2 | `EventName` | ~150 | <files> |
```
