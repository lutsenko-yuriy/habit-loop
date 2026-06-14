# Licensing decision — Habit Loop

This document records the research (WU1–WU3) and the chosen licence (WU4) for the Habit Loop source repository.

---

## WU1 — What a software licence does

A licence grants (or withholds) the right to use, copy, modify, and distribute the software. Without an explicit licence, copyright law applies by default: **all rights reserved, no reuse permitted**.

The main families:

| Family | Examples | Obligations for downstream users |
|---|---|---|
| Public-domain | CC0, Unlicense | None |
| Permissive | MIT, BSD-2, BSD-3 | Retain copyright notice and licence text |
| Permissive + patent | Apache 2.0 | Same as above; also includes explicit patent grant and retaliation clause |
| Weak copyleft | LGPL 2.1/3, MPL 2.0 | Modifications to *the library itself* must be released under the same licence |
| Strong copyleft | GPL v2, GPL v3 | Entire derivative work must be released under the same licence |
| Virulent copyleft | AGPL v3 | Same as GPL, plus network use triggers copyleft |
| Proprietary | "All rights reserved" | No reuse; controlled by the copyright holder |

**Source code licence vs. App Store distribution:** these are independent. A MIT-licensed codebase can be compiled and sold as a proprietary app on the App Store; the Store's own terms govern distribution, not the source licence. There is no conflict.

---

## WU2 — Recommendation

### Project goals

| Goal | Priority |
|---|---|
| Allow community contributions and forks | Low — solo project now, but may grow |
| Prevent competitors from white-labelling the app commercially | Low — no immediate commercial competitor concern |
| Keep implementation simple (no CLA, no dual-licencing) | High |
| Compatible with App Store / Play Store distribution | Required |
| No viral copyleft obligation on the app binary | Required |

### Candidates evaluated

| Licence | Pros | Cons | Verdict |
|---|---|---|---|
| MIT | Shortest text, universally understood, no patent clause | No patent protection | **Recommended** |
| Apache 2.0 | Adds patent grant + retaliation clause; preferred by Google/Firebase projects | Slightly longer, NOTICE file requirement | Strong second choice |
| GPL v2 | Strong copyleft | Incompatible with Apache-2.0 transitive deps (`fake_async`, `clock`, `material_color_utilities`) | **Ruled out** |
| Proprietary | Maximum control | Blocks contributions, no community openness | Viable if commercialisation is priority |

### Recommendation: **MIT**

MIT is the standard licence for Flutter/Dart open-source work, is compatible with every dependency in this project, and imposes no obligations beyond keeping the copyright notice. It leaves all options open for future monetisation or forking.

If the project is intended to remain closed-source (e.g., future paid app), the right choice is instead: **no LICENSE file / all rights reserved** (or a short proprietary notice).

---

## WU3 — Dependency compatibility audit

### Scope

All `pub.dev` packages declared in `pubspec.yaml` (direct) and selected high-risk transitive deps. No copy-pasted third-party source was found in `lib/` (scanned for copyright notices — zero hits).

### Direct dependencies

| Package | Declared licence | MIT compat | Apache 2.0 compat | Proprietary compat |
|---|---|---|---|---|
| intl | BSD-3-Clause | ✓ | ✓ | ✓ |
| collection | BSD-3-Clause | ✓ | ✓ | ✓ |
| cupertino_icons | MIT | ✓ | ✓ | ✓ |
| flutter_riverpod | MIT | ✓ | ✓ | ✓ |
| sqflite | MIT | ✓ | ✓ | ✓ |
| path | BSD-3-Clause | ✓ | ✓ | ✓ |
| firebase_core | BSD-3-Clause | ✓ | ✓ | ✓ |
| firebase_analytics | BSD-3-Clause | ✓ | ✓ | ✓ |
| firebase_crashlytics | BSD-3-Clause | ✓ | ✓ | ✓ |
| firebase_remote_config | BSD-3-Clause | ✓ | ✓ | ✓ |
| firebase_auth | BSD-3-Clause | ✓ | ✓ | ✓ |
| cloud_firestore | BSD-3-Clause | ✓ | ✓ | ✓ |
| talker_flutter | MIT | ✓ | ✓ | ✓ |
| shared_preferences | BSD-3-Clause | ✓ | ✓ | ✓ |
| flutter_local_notifications | BSD-3-Clause | ✓ | ✓ | ✓ |
| timezone | MIT | ✓ | ✓ | ✓ |
| flutter_timezone | MIT | ✓ | ✓ | ✓ |
| package_info_plus | BSD-3-Clause | ✓ | ✓ | ✓ |
| uuid | MIT | ✓ | ✓ | ✓ |
| google_sign_in | BSD-3-Clause | ✓ | ✓ | ✓ |
| connectivity_plus | BSD-3-Clause | ✓ | ✓ | ✓ |
| flutter_svg | MIT | ✓ | ✓ | ✓ |
| sqflite_common_ffi *(dev)* | MIT | ✓ | ✓ | ✓ |
| fake_async *(dev)* | Apache-2.0 | ✓ | ✓ | ✓ |
| flutter_lints *(dev)* | BSD-3-Clause | ✓ | ✓ | ✓ |

### Notable transitive dependencies

| Package | Declared licence | Notes |
|---|---|---|
| material_color_utilities | Apache-2.0 | Bundled inside the Flutter SDK; Apache-2.0 is compatible with MIT and proprietary |
| clock | Apache-2.0 | Dart team; transitive via `fake_async` |
| riverpod | MIT | Core of flutter_riverpod |
| state_notifier | MIT | Transitive via riverpod |
| meta | BSD-3-Clause | Dart team |
| characters | BSD-3-Clause | Flutter SDK |
| vector_math | BSD-2-Clause | Flutter SDK |
| stack_trace | BSD-3-Clause | Dart team |

### Result

**All dependencies are MIT, BSD-2-Clause, BSD-3-Clause, or Apache-2.0 — all permissive.** No copyleft library is present. Every candidate licence (MIT, Apache 2.0, proprietary) is compatible. GPL v2 is the only option ruled out by dependency compatibility.

---

## WU4 — Applied licence

*Pending decision. Once the licence is chosen:*

- Add `LICENSE` to the repo root.
- Add a licence badge / section to `README.md`.
- Update this section with the chosen licence and date.
- If MIT or Apache 2.0: no header files required in source.
- If a NOTICE file is required (Apache 2.0): add it at the repo root.
