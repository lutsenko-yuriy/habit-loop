---
name: dead-code-check
effort: RAPID
reasoning: MECHANICAL
output_style: CONCISE
description: Run the advisory dead-code detector to surface orphaned artefacts — l10n keys, analytics event classes, test files, and handler files — left behind after feature removals. Always exits 0; findings are advisory.
---

Run the dead-code detector and present the results.

---

## Steps

### 1. Run the detector

```bash
python3 scripts/dead_code/check.py
```

Use the Flutter project root as the working directory (auto-detected from script location — no `--root` flag needed when invoked from the repo root).

### 2. Present the output

Print the full report verbatim. Do not filter or reformat findings.

### 3. Triage guidance (optional)

If findings are present, offer to open a Linear ticket for any `[WARN]` section with more than one item. Do not open tickets automatically — wait for the user's instruction.
