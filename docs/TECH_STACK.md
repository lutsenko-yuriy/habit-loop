# Tech Stack

## Languages

| Language | Version | Used for |
|---|---|---|
| Dart | ^3.6.0 (`pubspec.yaml`) | Application code, tests |
| Swift | 5.0 (`ios/Runner.xcodeproj/project.pbxproj`) | iOS Siri/Shortcuts voice intents (`ios/Runner/Voice/`) |
| Kotlin | 2.2.20 (`android/settings.gradle.kts`) | Android host activity |
| Python | 3.12 (`.github/workflows/`) | Tooling scripts (`scripts/`) |
| Shell | bash | Claude Code hooks (`.claude/hooks/`), CI glue |

## Frameworks and libraries

- [Flutter](https://flutter.dev) stable channel (unpinned in CI) — UI framework
- [Riverpod](https://riverpod.dev) — state management and DI
- [sqflite](https://pub.dev/packages/sqflite) — local storage
- [Firebase](https://firebase.google.com) — Analytics, Crashlytics, Remote Config, Auth, Firestore, App Distribution
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) — scheduled reminders
- [Talker](https://pub.dev/packages/talker_flutter) — logging

## Platforms

- iOS 15.0+ (TestFlight)
- Android, Flutter-default minSdk (Firebase App Distribution)

## Tooling

- **Build / package manager:** pub (Flutter), Gradle 8.14, CocoaPods
- **Test runner:** `flutter test` (unit/widget), `flutter test integration_test/` (scenarios)
- **Linter / formatter:** `flutter analyze` (`flutter_lints`), `dart format -l 120`
- **CI:** GitHub Actions, Codecov
