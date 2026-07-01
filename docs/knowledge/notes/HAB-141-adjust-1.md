# HAB-141: Mid-session adjustment notes

## Notes

### 2026-07-01

**Dead code and unused functionality review — add to debrief checklist**

While fixing HAB-141, we discovered and removed the "Mark done" notification action button — a fully-implemented feature that had gone unnoticed for months. Removing it eliminated ~440 lines across 22 files (background isolate handler, foreground handler, analytics event, l10n keys in 4 locales, test files, fake service fields).

Two distinct concerns should be checked periodically:

1. **Dead code** (can be partially automated): orphaned handlers, analytics events, l10n strings, and test files left behind after a feature is removed. `flutter analyze` catches unused imports; a manual grep pass is needed for the rest.

2. **Unused functionality** (user-driven, product owner decision): features that work but are never used in practice. Cannot be detected automatically — the user identifies these based on real usage. A good prompt at debrief: "Are there any features you've shipped that you haven't seen yourself or users actually use?"

Add both checks to the debrief skill so they're asked every ticket, not just when someone happens to notice.

**Notes file template — standardise format**

All `docs/knowledge/notes/HAB-XX.md` files should be generated from a template so they look consistent. The `/note` skill (and debrief) should produce a file that follows a defined structure rather than free-form prose.

**Reopened tickets — convention for additional notes files**

When a ticket is reopened or revisited after its notes file has already been finalised, the original file stays as-is (treating it as a closed record). A new file is created with a suffix — e.g. `HAB-141-adjust-1.md`, `HAB-141-adjust-2.md` — to capture the new observations without overwriting history. Document this convention in the `/note` skill and in `docs/knowledge/README.md`.
