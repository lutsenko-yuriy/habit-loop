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
- `both` — both Android and iOS builds distributed
- `android` — only Android distributed
- `ios` — only iOS distributed

**CI/CD pipeline structure:**
```
check-skip (+ build gate) → test → resolve-version → build-android → distribute-android ─┐
                                                    → build-ios     → distribute-ios     ──┤
                                                                                           └→ version-tag (if ≥1 build succeeded)
```

`check-skip` runs `scripts/changelog/distribute.py` to determine `should_build`. Builds, distribution, and version tagging only run on the `main` branch when `should_build=true`. Feature branches run tests only and never build or tag.

**Selective build:** `check-skip` runs `scripts/changelog/distribute.py` to check whether the new CHANGELOG entries contain any `[user]` or `[app]` bullets. If not (e.g. a `[meta]`-only, `[ci]`-only, `[test]`-only, `[wip]`-only, or `[user-none]`-only entry), the entire build is skipped — no binary is produced, no build number is incremented, and no `version-*` tag is created. Because no `version-*` tag is created for build-skipped entries, `release_notes.py` automatically includes all `[user]` bullets from those and any subsequent entries when the next distributable build runs — preserving "What's New" aggregation across all unpublished releases.

**CHANGELOG tag taxonomy** (enforced by `scripts/changelog/lint.py`):

| Tag | Meaning | Triggers build? | Release notes? |
|---|---|---|---|
| `[user]` | User-visible app change | Yes | Yes |
| `[app]` | App code change, not user-visible | Yes | No |
| `[test]` | Test-only changes (unit tests, scenarios, widget tests) — no production code | No | No |
| `[meta]` | Skills / agent / workflow change | No | No |
| `[ci]` | CI/CD process change | No | No |
| `[user-none]` | Entire entry is internal-only (legacy sentinel) | No | No |
| `[wip]` | Intermediate WU merge in a multi-WU ticket — tests run, build entirely skipped, no `version-*` tag created | No | No |
| `[non-user]` | Supplementary bullet descriptor (not a classification) | — | No |

Every new `## [X.Y.Z]` entry must carry at least one classification tag (`[user]`, `[app]`, `[test]`, `[meta]`, `[ci]`, or `[user-none]`). The tag list may be extended; each new tag must declare its distribution and release-note behaviour.

**Release notes ("What's New"):**
- `scripts/changelog/release_notes.py` is run during `resolve-version` to produce user-friendly bullet-point release notes.
- It parses `docs/CHANGELOG.md`, extracts all entries with a version number *higher* than the last published version (determined from `version-*` git tags), and strips developer-only references (HAB-XX issue numbers, PR #XX, WU work-unit markers).
- Only `[user]` bullets are included; all other tags are silently excluded.
- Output is capped at 4 000 characters for compatibility with both Firebase App Distribution and App Store "What's New" fields.
- The generated notes are passed to both `distribute-android` and `distribute-ios` via a job output and written to `--release-notes-file` so Firebase testers see human-readable text instead of a build number/SHA string.
- A copy of the notes file is uploaded as a `release-notes` GitHub Actions artifact (retained for 90 days) for manual use in App Store / Play Store submissions.

**On-demand build cleanup:**
- Run `/cleanup-firebase [N] [--dry-run]` from Claude Code (skill: `skills/manage/cleanup-firebase/SKILL.md`).
- Deletes all Firebase App Distribution releases for both Android and iOS except the most recent N (default 10).
- Runs locally via `scripts/firebase/cleanup_builds.py` using `gcloud auth print-access-token` for authentication.
- Requires: `gcloud` CLI authenticated, `FIREBASE_ANDROID_APP_ID` and `FIREBASE_IOS_APP_ID` set in the environment.

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
| `FIREBASE_SERVICE_ACCOUNT_ANDROID` | `distribute-android` | Raw JSON of a GCP service account key with the Firebase App Distribution Admin role — paste the `.json` file content directly, no base64 |
| `FIREBASE_IOS_APP_ID` | `distribute-ios` | Firebase Console → iOS app → App ID (e.g. `1:123456789012:ios:abc123`) |
| `FIREBASE_SERVICE_ACCOUNT_IOS` | `distribute-ios` | Same as above — may reuse the Android service account JSON |
| `CODECOV_TOKEN` | `test` | Codecov upload token — obtain from [codecov.io](https://codecov.io) after connecting the repo; optional for public repos but recommended for reliability |
