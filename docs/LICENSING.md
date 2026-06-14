# Licensing decision — Habit Loop

This document records the research (WU1–WU3) and the chosen licence (WU4) for the Habit Loop source repository.

---

## WU1 — What a software licence does

A licence grants (or withholds) the right to use, copy, modify, and distribute the software. Without an explicit licence, copyright law applies by default: **all rights reserved, no reuse permitted**. This applies even to public repositories — pushing code to GitHub does not grant anyone the right to reuse it.

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

### Project context (as of June 2026)

- Solo developer, no plans to add contributors in the near future.
- Public GitHub repository — the code is visible to anyone.
- No commercial plans in the near future.
- Primary use case for sharing: studying purposes and showing the codebase to colleagues.
- The codebase is largely AI-generated (see section below on copyright implications).

### AI-generated code and copyright

A significant portion of Habit Loop's implementation was produced via AI-assisted ("vibe") coding with Claude. This has a real legal implication:

**Copyright requires human authorship.** The [US Copyright Office](https://www.copyright.gov/ai/ai_policy_guidance.pdf) (and most comparable jurisdictions) will not register purely AI-generated works. The legal status of AI-assisted code is still evolving, but the current consensus is:

- Code where a human provided architectural direction, domain modelling, prompt design, review, and approval likely retains *some* human authorship — but how much is an open question.
- Code generated mechanically with no meaningful human creative input may not be copyrightable at all.
- Anthropic's [Consumer Terms of Service](https://www.anthropic.com/legal/consumer-terms) (applicable here, as the code was produced via Claude.ai/Claude Code by an individual developer — not via the API under the [Commercial Terms](https://www.anthropic.com/legal/commercial-terms)) grant the user ownership of Claude's output (subject to applicable law), so Anthropic makes no competing ownership claim.

**Practical effect:** asserting strong proprietary rights ("all rights reserved") over AI-generated code is legally shakier than it would be for hand-written code. Conversely, applying a permissive open-source licence is more honest — you are explicitly allowing reuse rather than claiming exclusive rights you may not fully hold.

This does **not** mean licensing is pointless; it signals intent clearly and covers whatever human-authored portions exist (architecture decisions, naming, prompt design, test strategy, etc.).

### Project goals

| Goal | Priority |
|---|---|
| Allow colleagues to study and reference the code | High — explicit motivation for keeping the repo public |
| Allow community contributions and forks | Low — solo project, no plans for contributors |
| Prevent competitors from white-labelling the app commercially | Low — no immediate commercial concern |
| Keep implementation simple (no CLA, no dual-licencing) | High |
| Compatible with App Store / Play Store distribution | Required |
| No viral copyleft obligation on the app binary | Required |

### Candidates evaluated

| Licence | Pros | Cons | Verdict |
|---|---|---|---|
| **MIT** | Shortest text, universally understood, makes studying/sharing legally explicit, compatible with all deps | No patent protection; allows commercial forks | **Recommended when ready** |
| Apache 2.0 | Adds patent grant + retaliation clause; preferred by Google/Firebase projects | Slightly longer, NOTICE file requirement | Strong second choice |
| GPL v2 | Strong copyleft | Incompatible with Apache-2.0 transitive deps (`fake_async`, `clock`, `material_color_utilities`) | **Ruled out** |
| Proprietary / no licence | Maximum control by default | Legally prevents colleagues from reusing code; legally shakier for AI-generated work | Not recommended given stated goals |

### MIT vs. no licence — key comparison

| | No licence (current state) | MIT |
|---|---|---|
| Colleagues can legally study the code | ✗ Technically no — "all rights reserved" | ✓ Explicitly permitted |
| Colleagues can share snippets or fork the repo | ✗ Technically no | ✓ Yes |
| You retain copyright | ✓ (to whatever extent it exists) | ✓ (MIT does not waive copyright) |
| Someone can white-label and sell the app | Murky — legally they shouldn't, but practically hard to enforce over AI-generated code | ✓ They can (but must credit you) |
| Cost to apply | — | One file, ~5 minutes |
| Conventional for a public Flutter repo | ✗ Unusual to have no licence | ✓ Standard |

**Bottom line:** given that the stated goal is studying and sharing with colleagues, the current "no licence" state is technically at odds with that goal — every colleague looking at the code is in a legal grey zone. MIT resolves this cleanly and costs almost nothing.

### Recommendation: **MIT — but deferred**

MIT is the right choice for this project. It is the standard licence for Flutter/Dart open-source work, is compatible with every dependency, imposes no obligations beyond keeping the copyright notice, and aligns with the stated goal of making the code freely available to study.

**Why deferred and not applied now:**

1. The AI-generated code copyright question adds mild uncertainty about who owns what. While this doesn't change the recommendation, it's worth letting the legal landscape settle slightly — no urgency.
2. The project has no contributors, no commercial dependencies, and no immediate external pressure. The practical risk of the current "no licence" state is near zero today.
3. Applying the licence correctly requires one deliberate step (choosing the copyright holder name for the `LICENSE` file). Better done intentionally than rushed.

The licence question is **not cancelled** — it is parked at low priority until there is a reason to act (e.g., first external contributor, public launch, or simply a slow week).

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

## WU4 — Applying the licence (deferred — low priority)

When the time comes to apply MIT:

1. Create a `LICENSE` file at the repo root with the standard MIT text. The copyright line should read:
   ```
   Copyright (c) <year> <your full name>
   ```
2. Add a licence badge and one-line section to `README.md`:
   ```markdown
   ## Licence
   MIT — see [LICENSE](LICENSE)
   ```
3. No per-file headers are required — MIT does not mandate them.
4. No `NOTICE` file is required (that is an Apache 2.0 requirement).
5. Update this section with the chosen licence and the date applied.

**Trigger conditions** (any one is sufficient to act):
- First external contributor or pull request from outside the team.
- Public launch or App Store submission.
- The AI-generated code copyright landscape clarifies in a way that changes the calculus.
- Simply a good moment with no other priorities.
