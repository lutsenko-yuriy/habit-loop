# Versioning

The app follows [Semantic Versioning](https://semver.org/) with the Flutter version format `X.Y.Z+buildNumber` in `pubspec.yaml`.

**Version name (`X.Y.Z`):**
- **Major (X)** — breaking changes (incompatible file format, dropped platform support)
- **Minor (Y)** — new features (new counter operations, new platform support, new UI capabilities)
- **Patch (Z)** — bug fixes and small improvements

Version name changes are manual and require reasoning presented to the user before bumping.

**Build number (`+N`):**
- Auto-incremented by CI only on the `main` branch, after each pipeline run where at least one platform build succeeds.
- Synchronized across Android and iOS — both platforms always use the same build number.
- The CI commit message includes `[skip ci]` to prevent infinite loops.
- Feature branch builds do not bump the version, create tags, or distribute to Firebase.
- A `resolve-version` job runs before builds to prevent build number conflicts: it compares the `pubspec.yaml` build number against the highest existing `version-*` git tag and uses whichever is greater. Both platform builds receive this resolved number via `--build-number`.

**Git tags:** Created automatically by CI in the format `version-{X.Y.Z}-{buildNumber}-{suffix}` where suffix is:
- `both` — both Android and iOS builds succeeded
- `android` — only Android succeeded
- `ios` — only iOS succeeded

**CI/CD pipeline structure:**
```
check-skip → test → resolve-version → build-android → distribute-android ─┐
                                     → build-ios     → distribute-ios     ──┤
                                                                            └→ version-tag (if ≥1 build succeeded)
```

Distribution and version tagging only run on the `main` branch. Feature branches can still build (useful for testing) but won't distribute or tag.

**Required GitHub Actions Secrets:**

| Secret | Used by | How to obtain |
|---|---|---|
| `FIREBASE_OPTIONS_DART` | `test`, `build-android`, `build-ios` | `cat lib/firebase_options.dart \| base64` |
| `GOOGLE_SERVICES_JSON` | `build-android` | `cat android/app/google-services.json \| base64` |
| `GOOGLE_SERVICE_INFO_PLIST` | `build-ios` | `cat ios/Runner/GoogleService-Info.plist \| base64` |
| `KEY_STORE_BASE64` | `build-android` | `cat android/upload-keystore.jks \| base64` |
| `KEY_STORE_PASSWORD` | `build-android` | Keystore password |
| `KEY_PASSWORD` | `build-android` | Key password |
| `KEY_ALIAS` | `build-android` | Key alias |
| `IOS_CERTIFICATE_P12` | `build-ios` | `cat Distribution.p12 \| base64` (export from Keychain) |
| `IOS_CERTIFICATE_PASSWORD` | `build-ios` | Password set when exporting the .p12 |
| `IOS_PROVISIONING_PROFILE` | `build-ios` | `cat <profile>.mobileprovision \| base64` (ad-hoc profile from Apple Developer portal) |
| `IOS_TEAM_ID` | `build-ios` | 10-character Apple Developer Team ID (e.g. `ABCD1234EF`) |
| `FIREBASE_ANDROID_APP_ID` | `distribute-android` | Firebase Console → Android app → App ID (e.g. `1:123456789012:android:abc123`) |
| `FIREBASE_SERVICE_ACCOUNT_ANDROID` | `distribute-android` | Firebase service account JSON with App Distribution role |
| `FIREBASE_IOS_APP_ID` | `distribute-ios` | Firebase Console → iOS app → App ID (e.g. `1:123456789012:ios:abc123`) |
| `FIREBASE_SERVICE_ACCOUNT_IOS` | `distribute-ios` | Firebase service account JSON with App Distribution role (may reuse the Android service account) |
