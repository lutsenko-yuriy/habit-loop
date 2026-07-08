#!/usr/bin/env python3
"""strip_test_json.py — Remove non-JSON lines from test-results.json.

Flutter's --machine output occasionally includes non-JSON diagnostic lines
(e.g. VM service banners). dorny/test-reporter requires every line to be
valid JSON; this script drops the rest in-place.

Usage:
    python3 scripts/ci/strip_test_json.py [path]

The optional argument defaults to 'test-results.json'.
"""
import json
import pathlib
import sys


def is_json(line: str) -> bool:
    try:
        return isinstance(json.loads(line), (dict, list))
    except json.JSONDecodeError:
        return False


path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'test-results.json')
raw = path.read_text().splitlines()
clean = [line for line in raw if line.strip() and is_json(line)]
path.write_text('\n'.join(clean) + '\n')
