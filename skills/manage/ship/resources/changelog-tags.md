| Tag | When to use | Triggers distribution? | Appears in release notes? |
|---|---|---|---|
| `- [user] <description>` | User-visible app change | Yes | Yes — tag stripped |
| `- [app] <description>` | App code change, not user-visible | Yes | No |
| `- [test] <description>` | Test-only changes (unit tests, scenarios, widget tests) — no production code | No | No |
| `- [meta] <description>` | Skills / agent / workflow change | No | No |
| `- [ci] <description>` | CI/CD process change | No | No |
| `- [user-none]` | Entire entry is internal-only (legacy sentinel) | No | No |
| `- [non-user] <detail>` | Supplementary bullet within a classified entry | — | No |

Rules:
- **CI enforces this** (`scripts/changelog/lint.py` runs on every PR) — entries without a classification tag fail the build.
- Every `## [X.Y.Z]` entry must carry at least one of: `[user]`, `[app]`, `[test]`, `[meta]`, `[ci]`, or `[user-none]`.
- `[non-user]` is supplementary only — it does **not** satisfy the classification requirement on its own.
- `[user]` descriptions must pass a two-part check before writing: (a) would a user **without a background of developing apps understand** this? (b) would they **care**? If no to either, rewrite. No class names, file paths, RC key names, internal terms, or professional language (no "UX", "flow", "surface", "refactor", "migration", "parameter", "flag", etc.).
- **Common drift patterns to reject:**
  - ❌ Too technical: "Fixed RC parameter `pact_timeline_tail_size` off-by-one" → ✅ "Timeline now shows the right number of recent sessions"
  - ❌ Too designer-y: "Improved UX of the bottom sheet swipe interaction" → ✅ "The pact list is easier to open and close"
  - ❌ Too much detail: "Unified showup term to явка (RU), séance (FR), Showup (DE); fixed Fait→Réalisé (FR)" → ✅ "Improved translation consistency in French, German, and Russian"
  - ❌ Too product-manager-y: "Introduced commitment confirmation variant for EXP-003" → ✅ "New way to confirm your pact before creating it"
- When the [user] line needs to stay short but technical detail is worth preserving, add a companion `[app]` bullet on the next line.
- Place `[user]` lines before technical detail lines within the same section.
- The tag list may grow; each new tag must declare its distribution and release-note behaviour.
