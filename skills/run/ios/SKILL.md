---
name: run-ios
effort: RAPID
reasoning: MECHANICAL
needs_session_tools: true
output_style: CONCISE
description: Start the app on iOS. Prefers a connected physical device; falls back to a booted Simulator; if no Simulator is booted, boots the most recent iPhone Simulator and waits before starting the app.
---

Read `CLAUDE.local.md` for the Flutter binary path before running any command.

---

## Prerequisites — gitignored credential files

These files are not committed and must be present in the working tree before building.
If running from a git worktree, copy them from the main working directory first:

```bash
cp <main-project>/lib/firebase_options.dart lib/firebase_options.dart
cp <main-project>/ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
```

If either file is missing and the main project path is unknown, ask the user.

---

## Steps

### 1. List connected devices

```bash
<flutter> devices
```

Parse the output for iOS devices:
- **Physical device** — a line containing `ios` but NOT containing `simulator`.
- **Running simulator** — a line containing `simulator` or `Simulator`.

### 2a. Physical device found → run on it

```bash
<flutter> run -d <device-id>
```

Stop here.

### 2b. No physical device — check for a booted Simulator

If a booted Simulator appears in `flutter devices`, use it:

```bash
<flutter> run -d <simulator-device-id>
```

Stop here.

### 2c. No booted Simulator — boot one

List available simulators and find a suitable iPhone model:

```bash
xcrun simctl list devices available
```

Pick the most recent iPhone (e.g. the highest-numbered iPhone model that is available). Boot it:

```bash
xcrun simctl boot "<device-name-or-udid>"
open -a Simulator
```

Wait up to 60 seconds for the Simulator to appear in `flutter devices` by polling every 5 seconds:

```bash
<flutter> devices
```

Once the Simulator device ID appears, run:

```bash
<flutter> run -d <simulator-device-id>
```

### 3. No devices and no Simulators available

Report:

> "No iOS device or Simulator found. Connect a physical device or install an iOS Simulator runtime via Xcode → Settings → Platforms."

---

## Constraints

- Never use `flutter run` without `-d` — always specify the target device explicitly.
- Do not boot more than one Simulator.
- `flutter run` will stream logs to the terminal; leave it running in the foreground unless the user asks to stop it.
