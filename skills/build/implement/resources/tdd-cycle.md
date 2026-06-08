**Red — write failing tests first.**

- Mirror source under `test/`: `lib/slices/foo/domain/bar.dart` → `test/slices/foo/domain/bar_test.dart`.
- Run `<flutter binary> test <test-file>` to confirm failure before writing any implementation code.

**Green — implement the minimum code to pass.**

- Write only what is needed. Follow `docs/ARCHITECTURE.md` for structure and `docs/CODE_STYLE.md` for style.
- Vertical-slice structure:
  - Domain (`domain/`) — models, interfaces, pure business logic. No Flutter, no sqflite imports.
  - Data (`data/`) — repository implementations. Imports sqflite; depends on domain interfaces only.
  - UI generic (`ui/generic/`) — Riverpod notifiers and platform-agnostic helpers.
  - UI platform (`ui/ios/`, `ui/android/`) — Cupertino and Material widgets respectively.
- Never import across feature boundaries except through shared Riverpod providers.

**Refactor — clean up without breaking tests.**

Remove duplication, improve naming, simplify logic. Re-run `<flutter binary> test` after every step.
