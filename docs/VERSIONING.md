# Versioning

The app follows [Semantic Versioning](https://semver.org/) with the Flutter version format `X.Y.Z+buildNumber` in `pubspec.yaml`. For CI/CD pipeline mechanics, see `docs/CI_PIPELINE.md`.

**`pubspec.yaml`'s version represents the app's build version, not the repo's commit history (HAB-185).** It only advances for CHANGELOG entries that actually change the app — i.e. entries carrying at least one `[user]` and/or `[app]` tag. Entries classified only as `[ci]`/`[meta]`/`[test]`/`[wip]`/`[user-none]`/`[trivial]` never touch `pubspec.yaml` while they sit in `## [Unreleased]` (the default) — see "The `[Unreleased]` section" below. A `[trivial]`-only entry is the one exception that *can* still touch `pubspec.yaml`, but only if it's given its own numbered heading instead — via `ship --release-now`, which routes a `[trivial]`-only entry to a fresh numbered heading (patch bump) instead of the open `## [Unreleased]` batch (HAB-247 WU2; see the tag taxonomy table below).

**Version name (`X.Y.Z`):**
- **Major (X)** — breaking changes (incompatible file format, dropped platform support)
- **Minor (Y)** — new features (new counter operations, new platform support, new UI capabilities)
- **Patch (Z)** — bug fixes and small improvements

Version name changes are manual and require reasoning presented to the user before bumping.

**The `[Unreleased]` section (HAB-185):** CHANGELOG entries with no `[user]`/`[app]` tag land under a `## [Unreleased]` heading as plain bullets instead of getting their own numbered `## [X.Y.Z]` heading — `ship` never bumps `pubspec.yaml` for these. `## [Unreleased]` batches are **bounded, not one permanent bucket**: at most one is ever "open" (accumulating new bullets) at a time, sitting immediately before `docs/CHANGELOG.md`'s current first `## [...]` heading. The moment an app-changing entry ships, its new numbered heading inserts above the open batch, which becomes permanently **sealed** in place; a fresh `## [Unreleased]` then opens at the new top the next time it's needed. Sealed batches are never edited or folded into a later release once closed — this keeps the file scannable without any retroactive "which release does this belong to" calculation.

Because `## [Unreleased]` can appear multiple times in the file (one sealed per gap between releases, plus at most one open at the top), `scripts/changelog/{distribute,release_notes,lint}.py` compute each numbered entry's body boundary using the next `## [...]` heading of *any* kind (via the shared `scripts/changelog/heading_boundaries.py` helper) — not just the next numbered one. Otherwise a sealed batch's bullets would silently merge into the *newer* release's body.

Do not confuse this with the unrelated, legacy `(unreleased)` marker that appears inside some older entries' date parenthetical (e.g. `## [0.50.29] — 2026-07-17 (unreleased)`) — that predates HAB-185, marks a `[wip]` entry that still received a version number under the old scheme, and is left as-is.

**`[trivial]` is the one tag whose bullets survive sealing (HAB-247):** when a later release's numbered heading seals a batch containing `[trivial]` bullets, those bullets are not lost — `release_notes.py` emits them exactly once, alongside that sealing release's own `[user]` bullets, in the "What's New" text for that release's build. Every other tag inside an Unreleased batch (`[user]` included, per the HAB-185 invariant above) stays permanently invisible to release notes even after sealing.

**Build number (`+N`):**
- Auto-incremented by CI only on the `main` branch, after each pipeline run where at least one platform is successfully distributed — the increment lives in the resolved number and its `version-*` tag (see below), not in a `pubspec.yaml` commit.
- Synchronized across Android and iOS — both platforms always use the same build number.
- Feature branch builds do not bump the version, create tags, or distribute to Firebase.
- A `resolve-version` job runs before builds to prevent build number conflicts: it compares the `pubspec.yaml` build number against the highest existing `version-*` git tag and uses whichever is greater. Both platform builds receive this resolved number via `--build-number`.
- `version-tag` does **not** commit the resolved build number back to `pubspec.yaml` on `main` (HAB-241, following HAB-237's research) — it only pushes the `version-*` git tag. `pubspec.yaml`'s committed build number is therefore just a floor, expected to drift stale between releases; `resolve-version`'s max-of-pubspec-or-tag comparison keeps numbering monotonic regardless. This is also why `main` can require a PR for every branch write with zero bypass exceptions — CI has no remaining need to push commits directly to the branch.

**Git tags:** Created automatically by CI in the format `version-{X.Y.Z}-{buildNumber}-{suffix}` where suffix is:
- `both` — both Android (Firebase) and iOS (TestFlight) distributed
- `android` — only Android distributed
- `ios` — only iOS (TestFlight) distributed

`version-tag` gates on *either* `distribute-android` or `distribute-testflight` succeeding — a failure on one platform's distribution must never block tagging the release on the other's account (see HAB-180). Pipeline mechanics for both distribution jobs are in `docs/CI_PIPELINE.md`.

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
| `[trivial]` | Content-only change (copy/string/icon/asset), no logic or architecture impact | No by default (bullet sits in the open `## [Unreleased]` batch, invisible to the build gate) — Yes if given its own numbered `## [X.Y.Z]` heading, via `ship --release-now` when the user explicitly asks for an immediate release | Yes — either once its batch is sealed by a later release's numbered heading (emitted in that release's "What's New", HAB-247 WU2), or immediately if it shipped via `--release-now` under its own numbered heading |
| `[non-user]` | Supplementary bullet descriptor (not a classification) | — | No |

Every new `## [X.Y.Z]` entry must carry at least one classification tag (`[user]`, `[app]`, `[test]`, `[meta]`, `[ci]`, `[user-none]`, `[wip]`, or `[trivial]`). The tag list may be extended; each new tag must declare its distribution and release-note behaviour.

**Release notes ("What's New") — content rules:**
- `scripts/changelog/release_notes.py` produces user-friendly bullet-point release notes from `docs/CHANGELOG.md`, extracting all entries with a version number *higher* than the last published version (determined from `version-*` git tags), and stripping developer-only references (HAB-XX issue numbers, PR #XX, WU work-unit markers).
- `[user]` bullets from newer numbered entries are always included. `[trivial]` bullets are included too (HAB-247 WU2): from a newer numbered entry directly, or — uniquely among non-`[user]`/`[app]` tags — from a sealed `## [Unreleased]` batch, emitted once in the "What's New" of the release that sealed it. All other tags are silently excluded.
- Output is capped at 4 000 characters for compatibility with both Firebase App Distribution and App Store "What's New" fields.
- How this script's output is wired into the pipeline (which job runs it, how Firebase/TestFlight each consume it) is documented in `docs/CI_PIPELINE.md`.

For CI job graph, manual-dispatch inputs, TestFlight distribution, on-demand build cleanup, and required secrets/variables, see `docs/CI_PIPELINE.md`.
