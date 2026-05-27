#!/usr/bin/env python3
"""lint_changelog.py — Validate that new CHANGELOG entries have [user]/[user-none] markers.

Usage:
    python3 scripts/lint_changelog.py <changelog_path> [last_published_version]

    changelog_path          Path to docs/CHANGELOG.md
    last_published_version  Semver string like "0.30.2".  Only entries NEWER than
                            this version are checked.  Defaults to "0.0.0" (check
                            all entries).

Exit codes:
    0  All checked entries have at least one [user] bullet or [user-none] sentinel.
    1  One or more entries are missing markers — details printed to stdout.

Convention:
    Every new ## [X.Y.Z] entry must contain either:
      - At least one bullet starting with "- [user] ..."   (user-facing change)
      - The sentinel line                "- [user-none]"   (no user-visible impact)

    Developer-only bullets within a tagged entry should be prefixed with
    "- [non-user] ..." for clarity, but this is not enforced by this linter
    (only the [user] / [user-none] distinction matters for release notes).
"""

from __future__ import annotations

import re
import sys
from typing import Optional


# ---------------------------------------------------------------------------
# Semver helpers (duplicated from generate_release_notes.py to stay self-contained)
# ---------------------------------------------------------------------------

def _parse_semver(version: str) -> tuple[int, int, int]:
    parts = version.strip().split('.')
    if len(parts) != 3:
        raise ValueError(f'Not a semver string: {version!r}')
    return (int(parts[0]), int(parts[1]), int(parts[2]))


# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

_VERSION_HEADER = re.compile(r'^## \[(\d+\.\d+\.\d+)\]', re.MULTILINE)
_USER_TAG = re.compile(r'^\[user\]\s+')
_USER_NONE = re.compile(r'^\[user-none\]')


# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------

def lint(path: str, last_version: Optional[str]) -> list[str]:
    """Return a list of error messages for entries missing markers.

    An empty list means all checked entries are correctly marked.
    """
    with open(path, encoding='utf-8') as fh:
        content = fh.read()

    last_semver = _parse_semver(last_version) if last_version else (0, 0, 0)
    matches = list(_VERSION_HEADER.finditer(content))

    errors: list[str] = []

    for idx, match in enumerate(matches):
        version_str = match.group(1)
        try:
            semver = _parse_semver(version_str)
        except ValueError:
            continue

        if semver <= last_semver:
            break  # entries are newest-first; stop at or below the last published

        body_start = match.end()
        body_end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        body = content[body_start:body_end]

        has_user_bullet = False
        has_user_none = False

        for line in body.splitlines():
            stripped = line.strip()
            if not stripped.startswith('- '):
                continue
            text = stripped[2:]
            if _USER_NONE.match(text):
                has_user_none = True
                break
            if _USER_TAG.match(text):
                has_user_bullet = True
                break

        if not has_user_bullet and not has_user_none:
            errors.append(
                f'  [{version_str}]: missing [user] bullet or [user-none] sentinel\n'
                f'    Add "- [user] <user-facing description>" for each user-visible change,\n'
                f'    or "- [user-none]" if this release has no user-visible impact.'
            )

    return errors


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2:
        print(
            'Usage: lint_changelog.py <changelog_path> [last_published_version]',
            file=sys.stderr,
        )
        sys.exit(1)

    path = sys.argv[1]
    last_version = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        errors = lint(path, last_version)
    except Exception as exc:
        print(f'lint_changelog: error reading {path}: {exc}', file=sys.stderr)
        sys.exit(1)

    if errors:
        print('CHANGELOG lint failed — the following entries are missing markers:')
        print()
        for err in errors:
            print(err)
        print()
        print('Every new ## [X.Y.Z] entry must have at least one "- [user] ..." bullet')
        print('or the sentinel "- [user-none]" (for internal-only releases).')
        sys.exit(1)

    print(f'CHANGELOG lint passed — all new entries are correctly marked.')


if __name__ == '__main__':
    main()
