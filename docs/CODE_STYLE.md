# Code Style

## Base standard

Follow the [Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md) for all Dart and Flutter code. Everything below is an addition or clarification on top of it.

## Formatting

Line length: **120 characters**. Enforced by CI (`dart format -l 120 --set-exit-if-changed`).

Run before committing:

```bash
dart format -l 120 lib/ test/ integration_test/
```

Always commit formatting changes in a separate `style:` commit before functional changes.

## Linting

`package:flutter_lints` configured in `analysis_options.yaml`. CI runs `flutter analyze` and fails on any warning or error. Fix all findings before opening a PR — never assume a warning is pre-existing.

## Comments

**Comments are a last resort.** Code must be understandable through naming and structure alone. If you feel a comment is needed, first try renaming or restructuring.

Add a comment only when the **WHY** is genuinely non-obvious:

| Keep | Example |
|---|---|
| Hidden constraint or invariant | `// Must be called after super.initState — controller not ready before.` |
| Non-obvious platform behaviour | `// OverflowBox + IntrinsicHeight: LayoutBuilder throws inside CupertinoAlertDialog.` |
| PII rule | `// PII rule: habit name is user data — log length only, never the value.` |
| No-throw contract | `// NotificationService is no-throw — errors are swallowed internally.` |
| Non-obvious ordering requirement | `// Must invalidate cache before awaiting pact reload.` |

Never add:

- Narration of what the code does (`// Loop through slots and update each one`)
- Boilerplate field or class docs (`/// The current status.`)
- `// ---` or similar divider lines
- TODO / FIXME without a Linear ticket reference
- WHAT descriptions that the identifier already states

When a comment is unavoidable, keep it to **one concise line**. Multi-line comments are reserved for truly complex invariants (layout workarounds, algorithmic constraints) and must still be as short as possible.

## Control flow

Prefer flat control flow over nested conditionals — guard clauses first, then unindented code for the common case.

| Instead of | Prefer |
|---|---|
| `if (valid) { ...everything... }` | `if (!valid) return; ...everything...` |
| `if (a) { if (b) { ... } }` (single logical gate) | `if (a && b) { ... }` |
| Nesting past ~3 levels (`for` → `if` → `try`) | Extract the inner block into a well-named function |
| Wrapping a loop body in `if (shouldProcess(item)) { ... }` | `if (!shouldProcess(item)) continue;` at the top of the loop |

Nesting depth is a readability cost on its own, independent of line count.
