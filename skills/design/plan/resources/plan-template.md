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

### Implementation phases
1. **Phase 1 — <name>**: <what gets done; deliverable>
2. **Phase 2 — <name>**: <what gets done; deliverable>

### Work units
WU0 always contains integration scenarios only (no production code). Subsequent WUs should target ≤ 300 LoC changed and ≤ 10 files; split further if a WU would exceed these. Each WU lists which scenarios it makes green.

| # | Unit | Branch | Issues | Scenarios made green | Est. LoC | Files touched (approx) |
|---|------|--------|--------|----------------------|----------|------------------------|
| 0 | Integration scenarios (`draft-scenarios` output) | `feature/HAB-XX-WU0-scenarios` | HAB-XX | — (all start red) | ~50 | `integration_test/...` |
| 1 | <unit name> | `feature/HAB-XX-WU1-<short>` | HAB-XX | S1, S2 | ~150 | <files> |
```
