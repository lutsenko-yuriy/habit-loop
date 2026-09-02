# CI/CD Pipeline

Operational reference for the GitHub Actions pipeline: job graph, composite actions, manual-dispatch
inputs, granular standalone workflows, TestFlight distribution, and required secrets/variables.
For version numbering rules (semver, build numbers, CHANGELOG tags, release notes content), see
`docs/VERSIONING.md` — this file is CI mechanics only.

**Pipeline structure:** the automatic push/PR/main job graph lives in `.github/workflows/release.yml` (`name: release`; renamed from `ci.yml`/`build-and-deploy-apps` in HAB-183 — same triggers, same job graph, no behavior change):
```
check-skip (+ build gate + dispatch plan) → test → resolve-version → build-android → distribute-android ─┐
                                                                    → build-ios     → distribute-testflight ┼→ version-tag (if ≥1 platform distributed)
                                                                                     → set-testflight-notes (isolated — never blocks version-tag)
```

Job *bodies* are thin wrappers over shared composite actions in `.github/actions/` (`setup-flutter`, `restore-firebase-config`, `resolve-version`, `build-android-app`, `build-ios-app`, `run-tests`, `run-scenarios`) — introduced in HAB-183 to remove step-level duplication across jobs (and, from HAB-183 WU2 onward, across the granular manual-dispatch workflow files that reuse the same composites). Distribution steps (`distribute-android`, `distribute-testflight`, `set-testflight-notes`) stay inline — each is already a single script call, so a composite wrapper would add a layer without removing any duplication.

**Runs on `main` are serialized (HAB-264):** `release.yml` carries a top-level `concurrency: { group: release-${{ github.ref == 'refs/heads/main' && 'main' || github.run_id }}, cancel-in-progress: false }`. Two runs that could both build/tag on `main` (a push or a `workflow_dispatch` targeting `refs/heads/main`) share the `release-main` group and queue rather than race; every other run (PRs, other branches) gets a group unique to its own `run_id`, so it's never blocked by anything. This closes a real race in `resolve-version`: the highest `version-*` tag isn't written until `version-tag` runs — after both platform builds and distribution finish — so two overlapping runs could previously both read the same stale tag max and resolve the same build number.

**Selective build:** `check-skip` runs `scripts/changelog/distribute.py` to determine `should_build`, and `scripts/ci/dispatch_plan.py` to resolve per-job flags (`build_android`, `build_ios`, `distribute_android`, `distribute_testflight`, `group_alias`). `distribute.py` checks whether the new CHANGELOG entries contain any `[user]`, `[app]`, or (under its own numbered heading only — never inside `## [Unreleased]`) `[trivial]` bullets (see `docs/VERSIONING.md`'s tag taxonomy for what each tag means). If not (e.g. a `[meta]`-only, `[ci]`-only, `[test]`-only, `[wip]`-only, `[user-none]`-only, or `[Unreleased]`-batched `[trivial]`-only entry), the entire build is skipped — no binary is produced, no build number is incremented, and no `version-*` tag is created. Because no `version-*` tag is created for build-skipped entries, `release_notes.py` automatically includes all `[user]` bullets from those and any subsequent entries when the next distributable build runs — preserving "What's New" aggregation across all unpublished releases. Builds, distribution, and version tagging only run on the `main` branch when `should_build=true`. Feature branches run tests only and never build or tag.

**Manual dispatch (`workflow_dispatch`) inputs:**

| Input | Type | Default | Effect |
|---|---|---|---|
| `android` | boolean | `true` | Build the Android binary |
| `ios` | boolean | `true` | Build the iOS binary |
| `environment` | choice (`production`/`staging`) | `production` | `staging` suppresses distribution and sets `GROUP_ALIAS=staging-testers`, regardless of the two toggles below |
| `distribute_firebase` | boolean | `true` | Push to Firebase App Distribution — **Android only** (production only) — set `false` to validate a TestFlight-only run without notifying Firebase testers |
| `distribute_testflight` | boolean | `true` | Push to TestFlight — **iOS only** (production only) — set `false` to validate a Firebase-only run without uploading to App Store Connect |

`scripts/ci/dispatch_plan.py` translates these inputs into per-job flags consumed by `build-android`, `build-ios`, `distribute-android`, and `distribute-testflight`. `distribute_firebase` gates `distribute_android`; `distribute_testflight` gates `distribute_testflight` — so either distribution channel can be exercised independently on a manual dispatch.

**Granular manual-dispatch pipelines (HAB-183 WU2):** four additional `workflow_dispatch`-only files let a developer run a single procedure in isolation instead of paying for the full `release.yml` graph. None of them are triggered by push/PR, none of them touch `dispatch_plan.py` (that script's flag matrix stays bound to `release.yml` specifically), and all of them reuse the same composite actions under `.github/actions/` that `release.yml`'s own jobs use — see the reuse note above.

| File | Inputs | Runs |
|---|---|---|
| `test.yml` | none | The full test gate (`run-tests` composite: Python unit tests, CHANGELOG lint, `dart format` check, `flutter analyze`, `flutter test --coverage`, Codecov upload) on `ubuntu-latest`. |
| `build.yml` | `platform` (`android`/`ios`/`both`, default `both`), `environment` (`production`/`staging`, default **`staging`** — a lone validation build should not consume a real build number or require production secrets to be exercised) | `resolve-version` → `build-android` and/or `build-ios` per `platform`. No distribution, no `version-tag`. |
| `scenarios.yml` | none | Integration scenarios on the Android emulator (`run-scenarios` composite), independently of any `build-android` run in the same workflow — the slowest job (90 min timeout), and the one with the strongest case for standalone iteration. |
| `publish_changelogs.yml` | `build_number` (string, required), `version_name` (string, required) — identify an **already-uploaded** TestFlight build to (re)annotate | Generates release notes (`generate-release-notes` composite) and PATCHes them onto the given build via `scripts/appstore/set_testflight_whatsnew.py` — the same standalone What's-New path HAB-182 shipped. **iOS/TestFlight only** — Firebase (Android) has no equivalent standalone notes-update path; its release notes are set inside `distribute.sh` as part of a full upload, so a notes-only Android run isn't expressible without re-distributing the build. This asymmetry is intentional, not an oversight. |

Because `test.yml`/`build.yml`/`scenarios.yml`/`publish_changelogs.yml` are new files, none of them could be validated via `workflow_dispatch` before their introducing PR merged — GitHub only allows dispatching a workflow that already exists on the default branch (see `docs/knowledge/notes/HAB-183.md`). Each was live-dispatched on `main` immediately after merge instead.

**TestFlight distribution (HAB-167; sole iOS channel since HAB-180):** `scripts/appstore/testflight_upload.sh` uploads a signed IPA to TestFlight (internal testing) via `xcrun altool --upload-app` and an App Store Connect API key, mirroring `scripts/firebase/distribute.sh`. `build-ios` archives once and exports once — `method=app-store` — signed with the `IOS_APPSTORE_PROVISIONING_PROFILE` against the existing `IOS_CERTIFICATE_P12` Apple Distribution certificate. The app-store IPA is uploaded as the `ios-appstore` artifact and consumed by an isolated `distribute-testflight` job (`runs-on: macos-15`, gated on `distribute_testflight`, and automatic on every qualifying `main` merge — not just manual dispatch). It feeds `version-tag`'s OR-gate (see `docs/VERSIONING.md`) — its result determines the `ios`/`both` tag suffix, but a TestFlight failure alone never blocks tagging as long as `distribute-android` succeeded. Firebase App Distribution for iOS (and its ad-hoc export/signing path) was removed entirely in HAB-180; Android's Firebase distribution is unaffected.

**TestFlight "What's New" (HAB-182):** `scripts/appstore/set_testflight_whatsnew.py` runs in the isolated `set-testflight-notes` job (`runs-on: ubuntu-latest`, gated on `distribute-testflight` succeeding and `distribute_testflight == 'true'`) to give TestFlight testers the same release notes Firebase testers already get. Unlike `altool`, which has no release-notes parameter, this requires the App Store Connect REST API: build a short-lived ES256 JWT from the three existing `APP_STORE_CONNECT_*` secrets, resolve the app id from its bundle id, poll `GET /v1/builds` (default 30-minute timeout, 30s interval — both overridable via `POLL_TIMEOUT_SECONDS`/`POLL_INTERVAL_SECONDS`) until the just-uploaded build reaches `processingState=VALID`, then PATCH (or POST, if absent) the build's `betaBuildLocalizations` with the `resolve-version`-generated release notes. The script soft-fails — it exits 0 on a poll timeout or any API error, logging a warning instead — and the job also sets `continue-on-error: true` as a second layer of defence. It is deliberately **not** in `version-tag`'s `needs:`, mirroring `distribute-testflight`'s own isolation: a notes-update failure must never block release tagging, since the binary itself already uploaded successfully by this point.

**`build-ios` runs on `macos-26`** (not `macos-15`): Apple requires all App Store Connect uploads to be built with the iOS 26 SDK (Xcode 26+), which is only available on the `macos-26` runner image. `distribute-testflight` stays on `macos-15` — it only uploads the already-built IPA and has no SDK dependency.

**Release notes generation, wired into the pipeline:**
- `scripts/changelog/release_notes.py` runs during `resolve-version` to produce the user-friendly bullet-point release notes described in `docs/VERSIONING.md`.
- The generated notes are passed to `distribute-android` via a job output and written to `--release-notes-file` so Firebase testers see human-readable text instead of a build number/SHA string. `distribute-testflight` itself does not consume this output — `testflight_upload.sh` uploads the binary only via `xcrun altool`, which has no release-notes parameter — but the same `resolve-version` output is passed to the separate `set-testflight-notes` job (HAB-182, see above), which sets it as the build's "What's New" text via the App Store Connect REST API after Apple finishes processing the build.
- A copy of the notes file is uploaded as a `release-notes` GitHub Actions artifact (retained for 90 days) for manual use in App Store / Play Store submissions.

**On-demand build cleanup:**
- Run `/cleanup-firebase [N] [--dry-run]` from Claude Code (skill: `skills/manage/cleanup-firebase/SKILL.md`).
- Deletes all Firebase App Distribution releases for both Android and iOS except the most recent N (default 10).
- Runs locally via `scripts/firebase/cleanup_builds.py` using `gcloud auth print-access-token` for authentication.
- Requires: `gcloud` CLI authenticated, `FIREBASE_ANDROID_APP_ID` and `FIREBASE_IOS_APP_ID` set in the environment.

**Required GitHub Actions Secrets:**

| Secret | Used by | How to obtain | Status |
|---|---|---|---|
| `FIREBASE_OPTIONS_DART` | `restore-firebase-config` composite (`test`, `build-android`, `build-ios`, `run-scenarios` jobs; also `test.yml`, `build.yml`, `scenarios.yml`) | `cat lib/firebase_options.dart \| base64` | |
| `GOOGLE_SERVICES_JSON` | `restore-firebase-config` composite, `platform: android` (`build-android`, `run-scenarios`; also `build.yml`, `scenarios.yml`) | `cat android/app/google-services.json \| base64` | |
| `GOOGLE_SERVICE_INFO_PLIST` | `restore-firebase-config` composite, `platform: ios` (`build-ios`; also `build.yml`) | `cat ios/Runner/GoogleService-Info.plist \| base64` | |
| `KEY_STORE_BASE64` | `build-android-app` composite (`build-android`; also `build.yml`) | `cat android/upload-keystore.jks \| base64` | |
| `KEY_STORE_PASSWORD` | `build-android-app` composite (`build-android`; also `build.yml`) | Keystore password | |
| `KEY_PASSWORD` | `build-android-app` composite (`build-android`; also `build.yml`) | Key password | |
| `KEY_ALIAS` | `build-android-app` composite (`build-android`; also `build.yml`) | Key alias | |
| `IOS_CERTIFICATE_P12` | `build-ios-app` composite (`build-ios`; also `build.yml`) | `cat Distribution.p12 \| base64` (export from Keychain) | |
| `IOS_CERTIFICATE_PASSWORD` | `build-ios-app` composite (`build-ios`; also `build.yml`) | Password set when exporting the .p12 | |
| `IOS_PROVISIONING_PROFILE` | — | `cat <profile>.mobileprovision \| base64` (ad-hoc profile from Apple Developer portal) | DEPRECATED — fed the ad-hoc export path removed in HAB-180; no consumer remains |
| `IOS_APPSTORE_PROVISIONING_PROFILE` | `build-ios-app` composite (`build-ios`; also `build.yml`) | `cat <appstore>.mobileprovision \| base64` (App Store distribution profile for `com.habitloop.habitLoop`; reuses the same Apple Distribution certificate as `IOS_CERTIFICATE_P12`) | |
| `IOS_TEAM_ID` | `build-ios-app` composite (`build-ios`; also `build.yml`) | 10-character Apple Developer Team ID (e.g. `ABCD1234EF`) | |
| `FIREBASE_ANDROID_APP_ID` | `distribute-android` | Firebase Console → Android app → App ID (e.g. `1:123456789012:android:abc123`) | |
| `FIREBASE_SERVICE_ACCOUNT_ANDROID` | `distribute-android` | Raw JSON of a GCP service account key with the Firebase App Distribution Admin role — paste the `.json` file content directly, no base64 | |
| `FIREBASE_IOS_APP_ID` | `/cleanup-firebase` (local only) | Firebase Console → iOS app → App ID (e.g. `1:123456789012:ios:abc123`) | Still required — no longer used by CI (`distribute-ios` was removed in HAB-180), but still needed locally to clean up pre-HAB-180 iOS builds already in Firebase App Distribution |
| `FIREBASE_SERVICE_ACCOUNT_IOS` | — | Same as above — may reuse the Android service account JSON | DEPRECATED — was only used by `distribute-ios`, removed in HAB-180; not used by `/cleanup-firebase` (which authenticates via `gcloud auth print-access-token` instead) |
| `APP_STORE_CONNECT_API_KEY_P8` | `distribute-testflight`, `set-testflight-notes`; also `publish_changelogs.yml` | `cat AuthKey_<KEYID>.p8 \| base64` (App Store Connect → Users and Access → Integrations → API keys; role ≥ App Manager) — must be base64-encoded, matching the convention used by `IOS_CERTIFICATE_P12`/`IOS_APPSTORE_PROVISIONING_PROFILE`; `testflight_upload.sh` decodes it with `base64 --decode`, `set_testflight_whatsnew.py` with `base64.b64decode` | |
| `APP_STORE_CONNECT_KEY_ID` | `distribute-testflight`, `set-testflight-notes`; also `publish_changelogs.yml` | Key ID shown next to the API key in App Store Connect | |
| `APP_STORE_CONNECT_ISSUER_ID` | `distribute-testflight`, `set-testflight-notes`; also `publish_changelogs.yml` | Issuer ID shown on the API Keys page in App Store Connect | |
| `CODECOV_TOKEN` | `run-tests` composite (`test`; also `test.yml`) | Codecov upload token — obtain from [codecov.io](https://codecov.io) after connecting the repo; optional for public repos but recommended for reliability | |
| `GIST_TOKEN` | `run-scenarios` composite (`run-scenarios`; also `scenarios.yml`) | GitHub PAT with `gist` scope — used to update the scenarios badge gist; optional (badge update is skipped if absent) | |

**When adding a new secret that requires a specific encoding (e.g. base64):** before asking the user to add it to GitHub and run a live validation, verify the encode instruction in the table above and the decode step in the consuming script are symmetric. A mismatch here only surfaces as a runtime failure during a live `workflow_dispatch` run — never in code review or unit tests (this is exactly what happened in HAB-167).

**Required GitHub Actions Variables** (repository-level, not secrets):

| Variable | Used by | How to obtain |
|---|---|---|
| `SCENARIOS_GIST_ID` | `run-scenarios` | Create a public Gist at [gist.github.com](https://gist.github.com) with a file named `scenarios.json`; use the Gist ID from the URL. Update the badge URL in `README.md` to match. |
