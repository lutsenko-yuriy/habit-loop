| Tag | When to use | Triggers distribution? | Appears in release notes? |
|---|---|---|---|
| `- [user] <description>` | User-visible app change | Yes | Yes — tag stripped |
| `- [app] <description>` | App code change, not user-visible | Yes | No |
| `- [test] <description>` | Test-only changes (unit tests, scenarios, widget tests) — no production code | No | No |
| `- [meta] <description>` | Skills / agent / workflow change | No | No |
| `- [ci] <description>` | CI/CD process change | No | No |
| `- [user-none]` | Entire entry is internal-only (legacy sentinel) | No | No |
| `- [wip] <description>` | Intermediate WU merge in a multi-WU ticket | No | No |
| `- [trivial] <description>` | Content-only change (copy/string/icon/asset), no logic or architecture impact | No by default — rides along with the next real release; yes if given its own numbered heading | No by default; yes once it ships |
| `- [non-user] <detail>` | Supplementary bullet within a classified entry | — | No |

Rules:
- **CI enforces this** (`scripts/changelog/lint.py` runs on every PR) — entries without a classification tag fail the build.
- Every `## [X.Y.Z]` entry must carry at least one of: `[user]`, `[app]`, `[test]`, `[meta]`, `[ci]`, `[user-none]`, `[wip]`, or `[trivial]`.
- `[non-user]` is supplementary only — it does **not** satisfy the classification requirement on its own.
- `[user]` descriptions must pass the plain-language checklist before writing: @skills/manage/draft-release-notes/resources/user-bullet-checklist.md
- When the [user] line needs to stay short but technical detail is worth preserving, add a companion `[app]` bullet on the next line.
- Place `[user]` lines before technical detail lines within the same section.
- The tag list may grow; each new tag must declare its distribution and release-note behaviour.
