# HAB-141: Dashboard stale showup status after notification tap (reopened)

## Notes

### 2026-07-01

**Dead code and unused functionality review — add to debrief checklist**

While fixing HAB-141, we discovered and removed the "Mark done" notification action button — a fully-implemented feature that had gone unnoticed for months. Removing it eliminated ~440 lines across 22 files (background isolate handler, foreground handler, analytics event, l10n keys in 4 locales, test files, fake service fields).

Two distinct concerns should be checked periodically:

1. **Dead code** (can be partially automated): orphaned handlers, analytics events, l10n strings, and test files left behind after a feature is removed. `flutter analyze` catches unused imports; a manual grep pass is needed for the rest.

2. **Unused functionality** (user-driven, product owner decision): features that work but are never used in practice. Cannot be detected automatically — the user identifies these based on real usage. A good prompt at debrief: "Are there any features you've shipped that you haven't seen yourself or users actually use?"

Dead code checks should be automated (a hook or CI step) — tracked as a separate backlog item. Unused functionality review requires product-owner judgement and is harder to formalise.

**Unused functionality review — deferred, idea logged**

A periodic prompt (e.g. at session start via `/summarize`) to ask "anything in the app you haven't used or noticed users engaging with?" was considered but deferred — adding it to `/summarize` felt like scope creep toward a full triage flow. Revisit when there's a clearer home for it.

**Notes file template — standardise format**

All `docs/knowledge/notes/HAB-XX.md` files should be generated from a template so they look consistent. The `/note` skill (and debrief) should produce a file that follows a defined structure rather than free-form prose.

**Reopened tickets — convention for additional notes files**

When a ticket is reopened or revisited after its notes file has already been finalised, the original file stays as-is (treating it as a closed record). A new file is created with a suffix — e.g. `HAB-141-adjust-1.md`, `HAB-141-adjust-2.md` — to capture the new observations without overwriting history. Document this convention in the `/note` skill and in `docs/knowledge/README.md`.

## Debrief summary

### 2026-07-02

**What went well**
- Root cause identified precisely: `dashboardRefreshSignalProvider` was being written to a detached `ProviderContainer` instead of the widget tree's `ProviderScope` — fix was surgical
- Removing `_container` entirely after the fix was the right call; no leftover singleton
- The "Mark done" notification action cleanup was substantial (~440 lines, 22 files) and went smoothly once the decision was made

**What was hard or surprising**
- The first fix (PR #209) passed integration tests and looked correct but failed on a real device — the two-container split was subtle enough to fool the test harness
- The "Mark done" button had been shipped and wired correctly but went unnoticed for months — a reminder that features can be invisible even when they work

**What to change**
- Dead code detection should be automated (HAB-143 created): hooks or CI to catch orphaned handlers, analytics events, l10n keys, and test files after feature removal
- Unused functionality review is deferred — no clear home for it yet; revisit when a natural trigger emerges
- Notes file format standardised: `TEMPLATE.md` created; `/note` and `/debrief` updated to use it
- Reopened ticket convention documented: `HAB-XX-adjust-N.md` suffix instead of editing the original
- Debrief skill now reads existing notes before starting the dialog
