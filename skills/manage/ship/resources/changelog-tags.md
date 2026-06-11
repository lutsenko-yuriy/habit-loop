| Marker | When to use | What it does |
|---|---|---|
| `- [user] <description>` | User-visible change | Only `[user]`-tagged lines appear in release notes (tag stripped); all other bullets skipped |
| `- [user-none]` | **No** user-visible changes (CI fixes, refactors, tooling) | Entire entry silently omitted from release notes |
| `- [non-user] <detail>` | Developer-only detail within a tagged entry | Explicit marker for clarity; never appears in release notes |

Rules:
- **CI enforces this** (`scripts/changelog/lint.py` runs on every PR) — entries without `[user]` or `[user-none]` fail the build.
- Add `[user]` lines **before** technical detail lines in the same section.
- `[user]` descriptions must be plain English a non-technical user can understand — no class names, file paths, or jargon.
- Use `[user-none]` (as a single sentinel line) for PRs touching only tests, CI config, docs, internal refactors, or analytics instrumentation with no UI change; mark the remaining bullets `[non-user]`.
- Entries without any marker are silently skipped (same as `[user-none]`).
