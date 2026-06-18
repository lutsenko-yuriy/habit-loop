---
name: run-android
effort: RAPID
reasoning: MECHANICAL
needs_session_tools: true
output_style: CONCISE
description: Start the app on Android. Prefers a connected physical device; falls back to a running emulator; if no emulator is running, launches the first available AVD and waits for it to boot before starting the app.
---

Read `CLAUDE.local.md` for the Flutter binary path before running any command.

---

## Prerequisites — gitignored credential files

These files are not committed and must be present in the working tree before building.
If running from a git worktree, copy them from the main working directory first:

```bash
cp <main-project>/lib/firebase_options.dart lib/firebase_options.dart
cp <main-project>/android/app/google-services.json android/app/google-services.json
```

If either file is missing and the main project path is unknown, ask the user.

---

## Steps

### 1. List connected devices

```bash
<flutter> devices
```

Parse the output for Android devices:
- **Physical device** — a line containing `android` but NOT containing `emulator`.
- **Running emulator** — a line containing `emulator` or `android` with an ID like `emulator-5554`.

### 2a. Physical device found → hand off to the user

Report the device ID and tell the user to run in their terminal (or via `!` in Claude Code):

```
! <flutter-binary-path> run -d <device-id>
```

Stop here.

### 2b. No physical device — check for a running emulator

If a running emulator appears in `flutter devices`, hand off to the user:

```
! <flutter-binary-path> run -d <emulator-device-id>
```

Stop here.

### 2c. No running emulator — launch one

List available AVDs:

```bash
<flutter> emulators
```

Take the first AVD ID from the list and launch it:

```bash
<flutter> emulators --launch <avd-id>
```

Wait up to 60 seconds for the emulator to appear in `flutter devices` by polling every 5 seconds:

```bash
<flutter> devices
```

Once the emulator device ID appears, hand off to the user:

```
! <flutter-binary-path> run -d <emulator-device-id>
```

### 3. No devices and no AVDs available

Report:

> "No Android device or AVD found. Connect a physical device via USB or create an AVD in Android Studio (AVD Manager)."

---

## Constraints

- Never use `flutter run` without `-d` — always specify the target device explicitly.
- Do not start more than one emulator.
- All setup steps (device detection, emulator launch, boot wait) are executed by Claude. The final `flutter run` command is handed off to the user — it is interactive and long-running and cannot be executed by Claude.
