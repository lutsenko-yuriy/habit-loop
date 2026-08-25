Bullet syntax for CHANGELOG entries. Full tag semantics (meaning, build trigger, release-notes
behaviour) live in `docs/VERSIONING.md`'s tag taxonomy table — this file only adds the exact
bullet-writing syntax and a couple of process notes not covered there.

| When to use | Bullet syntax |
|---|---|
| User-visible app change | `- [user] <description>` |
| App code change, not user-visible | `- [app] <description>` |
| Test-only changes (unit tests, scenarios, widget tests) | `- [test] <description>` |
| Skills / agent / workflow change | `- [meta] <description>` |
| CI/CD process change | `- [ci] <description>` |
| Entire entry internal-only (legacy sentinel) | `- [user-none]` |
| Intermediate WU merge in a multi-WU ticket | `- [wip] <description>` |
| Content-only change (copy/string/icon/asset) | `- [trivial] <description>` |
| Supplementary bullet within a classified entry | `- [non-user] <detail>` |

Notes:
- **CI enforces classification** (`scripts/changelog/lint.py` runs on every PR) — see `docs/VERSIONING.md` for the full tag-taxonomy table and requirement.
- `[non-user]` is supplementary only — it does **not** satisfy the classification requirement on its own.
- `[user]` descriptions must pass the plain-language checklist before writing: @skills/manage/draft-release-notes/resources/user-bullet-checklist.md
- When the `[user]` line needs to stay short but technical detail is worth preserving, add a companion `[app]` bullet on the next line.
- Place `[user]` lines before technical detail lines within the same section.
