# Widget test gotchas

Known failure classes for "the widget exists but the test can't see it" — check these before reaching for print-and-inspect instrumentation.

- **Widget exists but the finder returns empty** → check `skipOffstage` (default `true` excludes content scrolled out of the viewport; scroll it into view first, or pass `skipOffstage: false`).
- **`pumpAndSettle` times out / hangs** → an indefinite animation (`CircularProgressIndicator`, etc.) never settles; use `tester.pump(duration)` instead.
- **Widget exists but `find` can't see it** → check for an ancestor `Offstage` or `Visibility(visible: false)`.

Add a new entry here whenever a fresh class of this kind gets diagnosed the hard way — see `skills/shared/decision-guidelines.md` guideline 4.
