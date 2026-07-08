#!/usr/bin/env python3
"""update_scenarios_badge.py — Update the shields.io Gist badge with pass/fail counts.

Reads test-results.json and PATCHes the Gist used by the scenarios badge in README.md.
Requires GIST_TOKEN and GIST_ID environment variables; exits cleanly if either is absent
(the CI step checks for them before calling this script).

Usage:
    GIST_TOKEN=<token> GIST_ID=<id> python3 scripts/ci/update_scenarios_badge.py [path]

The optional argument defaults to 'test-results.json'.
"""
import json
import os
import sys
import urllib.request


def _parse(path: str) -> tuple[int, int]:
    passed = total = 0
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
    except FileNotFoundError:
        pass
    return passed, total


path = sys.argv[1] if len(sys.argv) > 1 else 'test-results.json'
passed, total = _parse(path)

color = 'brightgreen' if passed == total and total > 0 else 'red'
badge = {'schemaVersion': 1, 'label': 'scenarios', 'message': f'{passed}/{total} passed', 'color': color}
payload = json.dumps({'files': {'scenarios.json': {'content': json.dumps(badge)}}})

req = urllib.request.Request(
    f'https://api.github.com/gists/{os.environ["GIST_ID"]}',
    data=payload.encode(),
    method='PATCH',
    headers={
        'Authorization': f'token {os.environ["GIST_TOKEN"]}',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
    },
)
try:
    with urllib.request.urlopen(req) as resp:
        print(f'Badge updated: {badge["message"]}')
except Exception as e:
    print(f'Failed to update badge: {e}', file=sys.stderr)
