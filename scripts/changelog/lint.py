#!/usr/bin/env python3
"""lint_changelog.py — Validate that new CHANGELOG entries are correctly tagged.

Usage:
    python3 scripts/changelog/lint.py <changelog_path> [last_published_version]

    changelog_path          Path to docs/CHANGELOG.md
    last_published_version  Semver string like "0.30.2".  Only entries NEWER than
                            this version are checked.  Defaults to "0.0.0" (check
                            all entries).

Exit codes:
    0  All checked entries pass.
    1  One or more entries have missing or invalid markers.

Tag taxonomy (enforced by this linter):

  Classification tags — every entry must have at least one:
    [user]      User-visible app change. Triggers distribution; appears in release notes.
    [app]       App source code change, not user-visible. Triggers distribution.
    [test]      Test-only changes (unit tests, scenarios, widget tests). No production code. No distribution.
    [meta]      Skills / agent / workflow change. No distribution.
    [ci]        CI/CD process change. No distribution.
    [user-none] Entire entry is internal-only (legacy sentinel, still accepted).

  Supplementary tag — describes an individual bullet but does not classify the entry:
    [non-user]  Developer-only detail within an entry that has a classification tag.

  Unknown tags — any [xxx] not in the set above — cause a lint failure.
"""

from __future__ import annotations

import re
import sys
from typing import Optional


# ---------------------------------------------------------------------------
# Semver helpers
# ---------------------------------------------------------------------------

def _parse_semver(version: str) -> tuple[int, int, int]:
    parts = version.strip().split('.')
    if len(parts) != 3:
        raise ValueError(f'Not a semver string: {version!r}')
    return (int(parts[0]), int(parts[1]), int(parts[2]))


# ---------------------------------------------------------------------------
# Tag sets
# ---------------------------------------------------------------------------

# All tags whose presence in a bullet is intentional.
KNOWN_TAGS: frozenset[str] = frozenset({
    'user', 'user-none', 'non-user',  # legacy / backward-compat
    'app', 'test', 'meta', 'ci',      # new taxonomy
    'wip',                            # intermediate WU merge — skips build and distribution
})

# Tags that classify an entry. Every entry must have at least one bullet
# whose tag is in this set. [non-user] is supplementary only.
CLASSIFICATION_TAGS: frozenset[str] = frozenset({
    'user', 'user-none', 'app', 'test', 'meta', 'ci', 'wip',
})


# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

_VERSION_HEADER = re.compile(r'^## \[(\d+\.\d+\.\d+)\]', re.MULTILINE)

# Matches "[tag]" at the start of a bullet's text (after the leading "- ").
_BRACKET_TAG = re.compile(r'^\[([^\]]+)\]')


# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------

def lint(path: str, last_version: Optional[str]) -> list[str]:
    """Return a list of error messages for entries with missing or invalid markers.

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

        has_classification = False
        unknown_tags: list[str] = []

        for line in body.splitlines():
            stripped = line.strip()
            if not stripped.startswith('- '):
                continue
            text = stripped[2:]  # drop leading "- "

            tag_match = _BRACKET_TAG.match(text)
            if tag_match:
                tag = tag_match.group(1)
                if tag not in KNOWN_TAGS:
                    unknown_tags.append(tag)
                elif tag in CLASSIFICATION_TAGS:
                    has_classification = True

        for tag in unknown_tags:
            errors.append(
                f'  [{version_str}]: unknown tag [{tag}]\n'
                f'    Known tags: {", ".join(sorted(KNOWN_TAGS))}'
            )

        if not has_classification:
            errors.append(
                f'  [{version_str}]: missing classification tag\n'
                f'    Add one of:\n'
                f'      "- [user] <description>"     — user-visible change (triggers distribution)\n'
                f'      "- [app] <description>"      — app code change, not user-visible (triggers distribution)\n'
                f'      "- [test] <description>"     — test-only changes, no production code (no distribution)\n'
                f'      "- [meta] <description>"     — skills/agent/workflow change (no distribution)\n'
                f'      "- [ci] <description>"       — CI/CD change (no distribution)\n'
                f'      "- [user-none]"              — entire entry is internal-only (no distribution)'
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
        print('CHANGELOG lint failed — the following entries have issues:')
        print()
        for err in errors:
            print(err)
        print()
        print('Every ## [X.Y.Z] entry must have at least one classification tag')
        print('and all [xxx] tags must be from the known set.')
        sys.exit(1)

    print('CHANGELOG lint passed — all new entries are correctly marked.')


if __name__ == '__main__':
    main()
