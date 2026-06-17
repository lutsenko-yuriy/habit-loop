#!/usr/bin/env python3
"""distribute.py — Decide whether new CHANGELOG entries warrant a Firebase distribution.

Usage:
    python3 scripts/changelog/distribute.py <changelog_path> [last_published_version]

    changelog_path          Path to docs/CHANGELOG.md
    last_published_version  Semver string like "0.30.2".  Only entries NEWER than
                            this version are examined.  Defaults to "0.0.0".

Output (stdout):
    'true'  — at least one new entry contains a [user] or [app] bullet.
    'false' — all new entries contain only [meta]/[ci]/[user-none]/[non-user] bullets.

Exit code: always 0 — never fails the CI pipeline.
"""

from __future__ import annotations

import re
import sys
from typing import Optional

_VERSION_HEADER = re.compile(r'^## \[(\d+\.\d+\.\d+)\]', re.MULTILINE)
_DISTRIBUTE_TAG = re.compile(r'^\[(user|app)\]')


def _parse_semver(version: str) -> tuple[int, int, int]:
    parts = version.strip().split('.')
    if len(parts) != 3:
        raise ValueError(f'Not a semver string: {version!r}')
    return (int(parts[0]), int(parts[1]), int(parts[2]))


def should_distribute(path: str, last_version: Optional[str]) -> bool:
    """Return True if any new CHANGELOG entry triggers distribution."""
    with open(path, encoding='utf-8') as fh:
        content = fh.read()

    last_semver = _parse_semver(last_version) if last_version else (0, 0, 0)
    matches = list(_VERSION_HEADER.finditer(content))

    for idx, match in enumerate(matches):
        version_str = match.group(1)
        try:
            semver = _parse_semver(version_str)
        except ValueError:
            continue

        if semver <= last_semver:
            break  # entries are newest-first; stop at or below last published

        body_start = match.end()
        body_end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        body = content[body_start:body_end]

        for line in body.splitlines():
            stripped = line.strip()
            if not stripped.startswith('- '):
                continue
            text = stripped[2:]
            if _DISTRIBUTE_TAG.match(text):
                return True

    return False


def main() -> None:
    if len(sys.argv) < 2:
        print(
            'Usage: distribute.py <changelog_path> [last_published_version]',
            file=sys.stderr,
        )
        sys.exit(1)

    path = sys.argv[1]
    last_version = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        result = should_distribute(path, last_version)
        print('true' if result else 'false')
    except Exception as exc:
        print(f'Warning: could not check distribution: {exc}', file=sys.stderr)
        print('true')  # safe fallback — distribute if in doubt


if __name__ == '__main__':
    main()
