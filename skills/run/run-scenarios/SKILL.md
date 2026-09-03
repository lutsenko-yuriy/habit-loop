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

Wrap the invocation in a hard 20-minute wrapper timeout (HAB-205) — a genuinely stuck run is indistinguishable from a slow one otherwise; it produces no error and can hang indefinitely, well past what a healthy full-suite run takes (~10 minutes).

`timeout` is GNU coreutils and is not present on macOS by default — resolve the binary first (falls back to no wrapper, with a warning, if neither is installed rather than silently failing with "command not found"):

```bash
TIMEOUT_BIN=$(command -v timeout || command -v gtimeout || true)
```

```bash
${TIMEOUT_BIN:+$TIMEOUT_BIN -k 1m 20m} <flutter> test <target> -d <device-id> --reporter expanded
```

If `TIMEOUT_BIN` is empty, tell the user once: "No `timeout`/`gtimeout` binary found (install via `brew install coreutils` for the hang-safety wrapper) — running without a wrapper timeout."

When `<target>` is a single specific file (HAB-XX match), run it directly. When it is the full suite, use `integration_test/test_runner.dart` as the target.

If the command exits with code 124, report a hang explicitly instead of a generic failure: "⏱️ Timed out after 20m — likely a runaway fixture/timing issue (HAB-205), not a slow-but-healthy run. Investigate before re-running."

If running this in the background, set up the monitor to emit on both success and
failure/error markers — not just a single "All tests passed" line — so a stalled or
crashed run is visible without the user having to ask.

### 4. Report

**All pass:**
> "✅ All scenarios pass — safe to `/ship`."

**Any fail:** list each failing test by name and the first assertion error. Do not invoke `ship`.
