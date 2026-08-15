---
name: run-ios
effort: RAPID
reasoning: MECHANICAL
needs_session_tools: true
output_style: CONCISE
description: Start the app on iOS. Prefers a booted Simulator; falls back to a wired physical device (with explicit permission); boots a Simulator if none is running. Wireless-only physical devices are skipped.
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
- **Physical device** — a line containing `ios` but NOT containing `simulator`. Note whether it says `(wireless)`.
- **Running simulator** — a line containing `simulator` or `Simulator`.

### 2a. Booted Simulator found → hand off to the user

```
! <flutter-binary-path> run -d <simulator-device-id>
```

Stop here.

### 2b. No booted Simulator — check for a physical device

**Wireless connection** (device line contains `(wireless)`): skip this device and fall through to 2c (boot a Simulator) instead — wireless LLDB attach has proven unreliable and resource-heavy on this machine (stuck attach, `CoreDeviceError`, high thermal load — see HAB-230). Tell the user why before falling through.

**Wired connection**: ask the user for explicit permission before handing off — running on physical hardware needs their go-ahead, not just a device being present. If granted, report the device ID and hand off:

```
! <flutter-binary-path> run -d <device-id>
```

Stop here. If declined, fall through to 2c instead.

### 2c. No usable device — boot a Simulator

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

Once the Simulator device ID appears, hand off to the user:

```
! <flutter-binary-path> run -d <simulator-device-id>
```

### 3. No devices and no Simulators available

Report:

> "No iOS device or Simulator found. Connect a physical device or install an iOS Simulator runtime via Xcode → Settings → Platforms."

---

## Constraints

- Never use `flutter run` without `-d` — always specify the target device explicitly.
- Do not boot more than one Simulator.
- Never hand off a run on a wired physical device without the user's explicit go-ahead first.
- Never hand off a run on a wireless-only physical device at all — fall back to a Simulator instead.
- All setup steps (device detection, Simulator boot, boot wait) are executed by Claude. The final `flutter run` command is handed off to the user — it is interactive and long-running and cannot be executed by Claude.
