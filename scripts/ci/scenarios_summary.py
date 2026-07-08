#!/usr/bin/env python3
"""scenarios_summary.py — Append an integration-test result table to $GITHUB_STEP_SUMMARY.

Reads test-results.json (Flutter --machine output, already stripped of non-JSON
lines by strip_test_json.py) and writes a Markdown summary table.

Usage:
    python3 scripts/ci/scenarios_summary.py [path]

The optional argument defaults to 'test-results.json'.
$GITHUB_STEP_SUMMARY must be set; falls back to /dev/null when absent (local use).
"""
import json
import os
import sys


def _parse(path: str) -> tuple[int, int, int]:
    passed = failed = total = 0
    try:
        for line in open(path):
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(event, dict):
                continue
            if event.get('type') == 'testDone' and not event.get('hidden', False):
                total += 1
                if event.get('result') == 'success':
                    passed += 1
                else:
                    failed += 1
    except FileNotFoundError:
        pass
    return passed, failed, total


path = sys.argv[1] if len(sys.argv) > 1 else 'test-results.json'
passed, failed, total = _parse(path)

status = '✅ passed' if failed == 0 and total > 0 else ('❌ failed' if total > 0 else '⚠️ no results')
summary = f"""## Integration scenarios — {status}

| Result | Count |
|--------|-------|
| ✅ Passed | {passed} |
| ❌ Failed | {failed} |
| Total | {total} |
"""
summary_path = os.environ.get('GITHUB_STEP_SUMMARY', '/dev/null')
with open(summary_path, 'a') as f:
    f.write(summary)
