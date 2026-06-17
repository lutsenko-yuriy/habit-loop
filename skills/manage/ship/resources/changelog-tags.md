| Tag | When to use | Triggers distribution? | Appears in release notes? |
|---|---|---|---|
| `- [user] <description>` | User-visible app change | Yes | Yes — tag stripped |
| `- [app] <description>` | App code change, not user-visible | Yes | No |
| `- [meta] <description>` | Skills / agent / workflow change | No | No |
| `- [ci] <description>` | CI/CD process change | No | No |
| `- [user-none]` | Entire entry is internal-only (legacy sentinel) | No | No |
| `- [non-user] <detail>` | Supplementary bullet within a classified entry | — | No |

Rules:
- **CI enforces this** (`scripts/changelog/lint.py` runs on every PR) — entries without a classification tag fail the build.
- Every `## [X.Y.Z]` entry must carry at least one of: `[user]`, `[app]`, `[meta]`, `[ci]`, or `[user-none]`.
- `[non-user]` is supplementary only — it does **not** satisfy the classification requirement on its own.
- `[user]` descriptions must be plain English a non-technical user can understand — no class names, file paths, or jargon.
- Place `[user]` lines before technical detail lines within the same section.
- The tag list may grow; each new tag must declare its distribution and release-note behaviour.
