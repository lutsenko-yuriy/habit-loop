# Code Style

## Base standard

Follow the [Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md) for all Dart and Flutter code. Everything below is an addition or clarification on top of it.

## Formatting

Line length: **120 characters** (wider than Flutter's 80-char default — fewer wrap-driven diffs on modern wide displays). Enforced by CI (`dart format -l 120 --set-exit-if-changed`).

Run before committing:

```bash
dart format -l 120 lib/ test/ integration_test/
```

Always commit formatting changes in a separate `style:` commit before functional changes — keeps logic diffs uncluttered by mechanical reformatting.

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
| Sequential `if (...) return false;` guards with nothing after them (a `.where()` predicate, a plain bool-returning getter) | Collapse into a single `&&`-chained expression |

Nesting depth is a readability cost on its own, independent of line count. Guard clauses earn their keep when there's a non-trivial body *after* the checks — when the entire body *is* the check, a single logical expression is more direct with no performance difference (Dart short-circuits `&&` the same way sequential early returns do).

## Avoid the ternary operator

Treat `cond ? a : b` as a code smell, even unnested — it reads worse under a quick scan than the alternatives below. Pick the replacement by shape:

**Two-way branch, one-off** → `if`/`else`:
```dart
// Instead of:
final label = hasName ? 'Hi, $name' : 'Dashboard';

// Prefer:
final String label;
if (hasName) {
  label = 'Hi, $name';
} else {
  label = 'Dashboard';
}
```

**Selecting over an enum or a fixed set of discrete cases** → `switch` expression — the compiler enforces exhaustiveness, so a new enum value fails to compile instead of silently falling through:
```dart
// Instead of:
final icon = isOnBreak ? Icons.pause_circle_filled : isInProgress ? Icons.access_time_filled : Icons.check_circle;

// Prefer:
final icon = switch (uiState) {
  ShowupUiState.onBreak => Icons.pause_circle_filled,
  ShowupUiState.waitingForStart || ShowupUiState.active => Icons.access_time_filled,
  ShowupUiState.done => Icons.check_circle,
  ...
};
```

**The same conditional logic is needed in more than one place, or the condition itself needs a name to be legible** → extract a helper function/method:
```dart
// ShowupStatusColors.forUiState(state) — used by the calendar dots, the detail
// badge, and the todo-list tile, instead of three copies of the same switch.
Color forUiState(ShowupUiState state) => switch (state) {
      ShowupUiState.planned => pending,
      ShowupUiState.waitingForStart || ShowupUiState.active => waitingForStart,
      ShowupUiState.onBreak => onBreak,
      ShowupUiState.done => done,
      ShowupUiState.failed => failed,
    };
```

## Git hygiene

Before the first `git add -A`/commit on a new feature branch, run `git status` and check for pre-existing untracked/modified files unrelated to this ticket — stage only what belongs to the change (`git add <specific files>`) rather than `-A`, to avoid sweeping unrelated working-tree state into the PR (HAB-228: an untracked local config file and a leftover investigation test both got swept into a PR this way, each needing its own cleanup commit).
