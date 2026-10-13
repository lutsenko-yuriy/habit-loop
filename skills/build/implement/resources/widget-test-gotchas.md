# Widget test gotchas

Known failure classes for "the widget exists but the test can't see it" — check these before reaching for print-and-inspect instrumentation.

- **Widget exists but the finder returns empty** → check `skipOffstage` (default `true` excludes content scrolled out of the viewport; scroll it into view first, or pass `skipOffstage: false`).
- **`pumpAndSettle` times out / hangs** → an indefinite animation (`CircularProgressIndicator`, etc.) never settles; use `tester.pump(duration)` instead.
- **Widget exists but `find` can't see it** → check for an ancestor `Offstage` or `Visibility(visible: false)`.
- **`ensureVisible` scrolls the wrong amount (or not at all)** → it computes the scroll target against the *current* RenderBox geometry; if a keyboard-inset relayout is still in flight, a bare `pump()` doesn't advance enough virtual time for it to settle first, so `ensureVisible` under-scrolls and `tap()` misses the widget once the inset finishes animating in. Pump the full transition duration (e.g. 350ms+) *before* calling `ensureVisible`, not just after.

Add a new entry here whenever a fresh class of this kind gets diagnosed the hard way — see `skills/shared/decision-guidelines.md` guideline 4.
