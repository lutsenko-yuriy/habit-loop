---
name: run-scenarios
effort: RAPID
reasoning: MECHANICAL
needs_session_tools: true
output_style: CONCISE
description: Run integration test scenarios locally before merging. Finds a running device, executes flutter test integration_test/, and reports pass/fail with a per-scenario breakdown. Invoke after the review loop passes and before invoking ship. Optionally accepts a HAB-XX ticket number to run only that ticket's scenario files.
---

Read `CLAUDE.local.md` for the Flutter binary path before running any command.

---

## Steps

### 1. Find a running device

```bash
<flutter> devices
```

Pick the first available device — prefer a connected physical device; fall back to a booted Simulator or emulator.

If no device is found, stop and report:

> "No device running. Start one first with `/ios` or `/android`, then re-invoke `/run-scenarios`."

### 2. Determine the test target

**With a HAB-XX argument:** find matching scenario files:

```bash
find integration_test/ -iname "*hab*<N>*"
```

If files are found, run only those. If none match, fall back to the full suite and note the fallback.

**Without an argument:** run the full suite via the combined runner to avoid per-file reinstall overhead — `integration_test/test_runner.dart`.

### 3. Run

```bash
<flutter> test <target> -d <device-id> --reporter expanded
```

When `<target>` is a single specific file (HAB-XX match), run it directly. When it is the full suite, use `integration_test/test_runner.dart` as the target.

If running this in the background, set up the monitor to emit on both success and
failure/error markers — not just a single "All tests passed" line — so a stalled or
crashed run is visible without the user having to ask.

### 4. Report

**All pass:**
> "✅ All scenarios pass — safe to `/ship`."

**Any fail:** list each failing test by name and the first assertion error. Do not invoke `ship`.
