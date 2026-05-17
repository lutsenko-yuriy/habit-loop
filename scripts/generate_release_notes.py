#!/usr/bin/env python3
"""generate_release_notes.py — Extract user-friendly release notes from CHANGELOG.md.

Usage:
    python3 scripts/generate_release_notes.py <changelog_path> [last_published_version]

    changelog_path          Path to docs/CHANGELOG.md
    last_published_version  Semver string like "0.30.2" (extracted from the latest
                            version-* git tag).  If omitted or "0.0.0", all entries
                            are included.

Output (stdout):
    Human-readable bullet list covering every version newer than
    last_published_version, truncated to 4 000 characters — compatible with both
    Firebase App Distribution and App Store "What's New" fields.

Bullet selection (per CHANGELOG entry):
    - If an entry contains ANY bullets prefixed with "[user] ", only those bullets
      are included (with the "[user] " tag stripped).  This is the preferred
      approach for entries going forward — mark exactly which lines users care about.
    - If an entry contains NO "[user] " bullets, all bullets are included after
      stripping internal references (HAB-XX, PR #XX, WU work-unit markers).
      This is the backwards-compatible fallback for older entries.

Convention for CHANGELOG authors:
    Prefix user-facing bullets with "[user] ":
        - [user] Sign-in button stays visible while Google login is in progress
        - isSigningIn guard extended to cover auth state flip  ← developer-only, not shown

Exit codes:
    0  Success (notes written to stdout).
    0  Fallback on any error — prints a safe default and exits 0 so it never
       breaks the CI pipeline.
"""

from __future__ import annotations

import re
import sys
from typing import Optional


# ---------------------------------------------------------------------------
# Semver helpers
# ---------------------------------------------------------------------------

def _parse_semver(version: str) -> tuple[int, int, int]:
    """Parse 'X.Y.Z' into a sortable tuple. Raises ValueError on bad input."""
    parts = version.strip().split('.')
    if len(parts) != 3:
        raise ValueError(f'Not a semver string: {version!r}')
    return (int(parts[0]), int(parts[1]), int(parts[2]))


# ---------------------------------------------------------------------------
# Cleaning helpers
# ---------------------------------------------------------------------------

# Patterns to strip from individual bullet lines.
_CLEANUP_PATTERNS: list[re.Pattern[str]] = [
    # Issue references: (HAB-55), HAB-55, HAB-12/HAB-13 etc.
    re.compile(r'\s*\(?HAB-\d+(?:[,/]\s*HAB-\d+)*\)?'),
    # PR references: (PR #92 merged), PR #92
    re.compile(r'\s*\(?PR\s*#\d+(?:\s+merged)?\)?'),
    # Work-unit prefixes: "WU4 of HAB-53", "WU4/"
    re.compile(r'\s*WU\d+\s+of\s+', re.IGNORECASE),
    re.compile(r'\bWU\d+/\s*', re.IGNORECASE),
    # Test/analyzer status lines (developer-only noise).
    re.compile(r'\d+\s+tests?\s+passing.*', re.IGNORECASE),
    re.compile(r'analyzer\s+clean.*', re.IGNORECASE),
]

# Lines that are purely internal and add no value to end-users.
_SKIP_LINE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r'^\d+\s+tests?\s+pass', re.IGNORECASE),
    re.compile(r'^analyzer\s+clean', re.IGNORECASE),
    re.compile(r'^\[skip ci\]', re.IGNORECASE),
]


def _clean_bullet(text: str) -> str:
    """Remove internal references from a single bullet-point string."""
    for pattern in _CLEANUP_PATTERNS:
        text = pattern.sub('', text)
    # Tidy up multiple spaces and trailing punctuation/whitespace.
    text = re.sub(r'  +', ' ', text)
    text = text.rstrip(' ,;:')
    return text.strip()


def _should_skip(text: str) -> bool:
    return any(p.search(text) for p in _SKIP_LINE_PATTERNS)


# ---------------------------------------------------------------------------
# CHANGELOG parsing
# ---------------------------------------------------------------------------

# Matches "## [0.30.2] — 2026-05-15 (PR #84 merged)" etc.
_VERSION_HEADER = re.compile(r'^## \[(\d+\.\d+\.\d+)\]', re.MULTILINE)

# Matches the "[user] " prefix that marks a bullet as user-facing.
_USER_TAG = re.compile(r'^\[user\]\s+')


def _parse_changelog(path: str, last_version: Optional[str]) -> list[str]:
    """Return user-facing bullet strings for all versions newer than last_version.

    Per-entry selection logic:
    - If the entry has ≥1 "[user] "-tagged bullet, only those are returned
      (tag stripped).  Developer-only lines are silently skipped.
    - If the entry has no "[user] " bullets (old-style entry), all non-skip
      lines are returned after stripping internal references — backwards-
      compatible fallback.
    """
    with open(path, encoding='utf-8') as fh:
        content = fh.read()

    last_semver = _parse_semver(last_version) if last_version else (0, 0, 0)
    matches = list(_VERSION_HEADER.finditer(content))
    if not matches:
        return []

    bullets: list[str] = []

    for idx, match in enumerate(matches):
        version_str = match.group(1)
        try:
            semver = _parse_semver(version_str)
        except ValueError:
            continue

        if semver <= last_semver:
            # Entries are newest-first in the file; stop as soon as we hit
            # a version that's at or before the last published one.
            break

        # Body spans from end of this header to start of the next (or EOF).
        body_start = match.end()
        body_end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        body = content[body_start:body_end]

        user_bullets: list[str] = []
        fallback_bullets: list[str] = []

        for line in body.splitlines():
            stripped = line.strip()
            if not stripped.startswith('- '):
                continue
            text = stripped[2:]  # drop leading "- "

            if _USER_TAG.match(text):
                # Explicitly marked as user-facing — strip the tag and keep.
                user_bullets.append(_USER_TAG.sub('', text, count=1).strip())
            else:
                # Collect for the fallback path (used only if no [user] tags).
                if not _should_skip(text):
                    cleaned = _clean_bullet(text)
                    if cleaned:
                        fallback_bullets.append(cleaned)

        # Prefer explicit [user] bullets; fall back to filtered set for old entries.
        bullets.extend(user_bullets if user_bullets else fallback_bullets)

    return bullets


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

_MAX_CHARS = 4000
_ELLIPSIS = '…'


def _format(bullets: list[str]) -> str:
    if not bullets:
        return 'Bug fixes and improvements.'

    lines = [f'• {b}' for b in bullets]
    result = '\n'.join(lines)

    if len(result) > _MAX_CHARS:
        # Truncate cleanly at a bullet boundary.
        truncated: list[str] = []
        total = 0
        for line in lines:
            needed = len(line) + (1 if truncated else 0)  # +1 for '\n'
            if total + needed + len(_ELLIPSIS) + 1 > _MAX_CHARS:
                break
            truncated.append(line)
            total += needed
        result = '\n'.join(truncated) + '\n' + _ELLIPSIS

    return result


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2:
        print(
            'Usage: generate_release_notes.py <changelog_path> [last_published_version]',
            file=sys.stderr,
        )
        sys.exit(1)

    changelog_path = sys.argv[1]
    last_version = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        bullets = _parse_changelog(changelog_path, last_version)
        print(_format(bullets))
    except Exception as exc:  # noqa: BLE001
        # Never fail the CI build — just emit a safe fallback.
        print(f'Warning: could not generate release notes: {exc}', file=sys.stderr)
        print('Bug fixes and improvements.')


if __name__ == '__main__':
    main()
