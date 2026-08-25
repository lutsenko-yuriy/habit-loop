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
      are included (with the "[user] " tag stripped).  This is the required
      approach — mark exactly which lines users care about.
    - "[trivial] "-prefixed bullets are also included, tag stripped (HAB-247):
      from a newer numbered entry directly, or — the one exception to the rule
      below — from a sealed "## [Unreleased]" batch, emitted once in the notes
      for the release that sealed it.  A still-open batch (no release above it
      yet) contributes nothing.
    - If an entry contains the sentinel "- [user-none]", the entry is silently
      skipped (contributes nothing to the output).  Use this for releases that
      are purely internal (CI fixes, refactors, tooling) with no user-visible
      impact.
    - If an entry contains NEITHER "[user] " nor "[trivial] " bullets NOR
      "[user-none]", it is also silently skipped.  Entries MUST be explicitly
      marked — see convention below.  Use scripts/lint_changelog.py in CI to
      catch unmarked entries.

Convention for CHANGELOG authors (enforced by scripts/lint_changelog.py):
    - User-facing change:       - [user] Sign-in button stays visible during Google login
    - Developer-only line:      - [non-user] isSigningIn guard extended to cover auth state flip
    - Nothing for users at all: - [user-none]
    Every new ## entry must carry at least one classification tag ([user], [app], [test],
    [meta], [ci], or [user-none]). Entries without [user] bullets produce no release notes.

Exit codes:
    0  Success (notes written to stdout).
    0  Fallback on any error — prints a safe default and exits 0 so it never
       breaks the CI pipeline.
"""

from __future__ import annotations

import re
import sys
from typing import Optional

try:
    from changelog.heading_boundaries import body_end_for, heading_entries
except ImportError:
    from heading_boundaries import body_end_for, heading_entries


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
    # Work-unit markers in any house-style shape: "WU4 of HAB-53", "WU4/",
    # "WU3 (final):", "(WU3)" bare. Self-contained (doesn't depend on the
    # HAB-\d+ pattern above having already run) — see HAB-252 audit finding,
    # where a HAB-\d+ match preceding "WU3 (final): " left the WU marker
    # behind because the old pattern only matched "WU\d+ of ".
    re.compile(r'\s*\(?WU\d+(?:\s*\([^()]*\))?\s*(?:of\s+|/\s*|:\s*)?\)?', re.IGNORECASE),
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
    # Tidy up multiple spaces and stray punctuation left at either end once a
    # reference like "HAB-55: " (leading) or "(PR #92)" (trailing) is removed.
    text = re.sub(r'  +', ' ', text)
    text = text.strip(' ,;:-')
    return text.strip()


def _should_skip(text: str) -> bool:
    return any(p.search(text) for p in _SKIP_LINE_PATTERNS)


# ---------------------------------------------------------------------------
# CHANGELOG parsing
# ---------------------------------------------------------------------------

# Matches the "[user] " prefix that marks a bullet as user-facing.
_USER_TAG = re.compile(r'^\[user\]\s+')
# Matches the "[user-none]" sentinel that explicitly suppresses an entry.
_USER_NONE = re.compile(r'^\[user-none\]')
# Matches the "[trivial] " prefix (HAB-247) — content-only bullets that ride
# along in ## [Unreleased] until a later release seals their batch. Requires
# trailing whitespace like _USER_TAG, so a concatenated multi-tag bullet
# (e.g. "[trivial][meta] ...", the repo's actual style for Unreleased
# bullets) or a bare "[trivial]" sentinel is correctly excluded rather than
# partially stripped into malformed output.
_TRIVIAL_TAG = re.compile(r'^\[trivial\]\s+')


def _parse_changelog(path: str, last_version: Optional[str]) -> list[str]:
    """Return user-facing bullet strings for all versions newer than last_version.

    Single pass over every '## [...]' heading, newest-first:
    - A numbered heading at or below last_version stops the scan (entries are
      newest-first). A newer numbered heading contributes its "[user] "
      bullets (tag stripped, "[user-none]" suppresses the whole entry) plus
      its "[trivial] " bullets (tag stripped, no suppression).
    - An "## [Unreleased]" heading contributes only "[trivial] " bullets, and
      only once at least one numbered heading has already been seen in this
      pass — i.e. the batch is sealed, not the still-open batch at the top of
      the file. HAB-185's invariant is otherwise unchanged: "[user]" bullets
      and "[user-none]" sentinels inside any Unreleased batch are ignored.
    """
    with open(path, encoding='utf-8') as fh:
        content = fh.read()

    last_semver = _parse_semver(last_version) if last_version else (0, 0, 0)
    entries = heading_entries(content)
    if not entries:
        return []

    all_headings = [start for start, _ in entries]
    bullets: list[str] = []
    seen_numbered = False

    for start, label in entries:
        # Body spans from end of this header line to the start of the next
        # heading of ANY kind (or EOF) — so a sealed ## [Unreleased] batch is
        # never absorbed into an adjacent entry's body (HAB-185).
        body_start = content.index(']', start) + 1
        body_end = body_end_for(start, all_headings, len(content))
        body = content[body_start:body_end]

        if label == 'Unreleased':
            if not seen_numbered:
                continue  # still-open batch — not sealed by any release yet
            for line in body.splitlines():
                stripped = line.strip()
                if not stripped.startswith('- '):
                    continue
                text = stripped[2:]
                if _TRIVIAL_TAG.match(text):
                    cleaned = _clean_bullet(_TRIVIAL_TAG.sub('', text, count=1).strip())
                    if cleaned and not _should_skip(cleaned):
                        bullets.append(cleaned)
            continue

        try:
            semver = _parse_semver(label)
        except ValueError:
            continue

        if semver <= last_semver:
            # Entries are newest-first in the file; stop as soon as we hit
            # a version that's at or before the last published one.
            break

        seen_numbered = True
        user_bullets: list[str] = []
        trivial_bullets: list[str] = []
        suppress_entry = False

        for line in body.splitlines():
            stripped = line.strip()
            if not stripped.startswith('- '):
                continue
            text = stripped[2:]  # drop leading "- "

            if _USER_NONE.match(text):
                # Author explicitly declared: no user-facing changes in this entry.
                suppress_entry = True
                break
            elif _USER_TAG.match(text):
                # Explicitly marked as user-facing — strip the tag, then scrub
                # any developer-only reference that slipped past authoring
                # convention (HAB-252).
                cleaned = _clean_bullet(_USER_TAG.sub('', text, count=1).strip())
                if cleaned and not _should_skip(cleaned):
                    user_bullets.append(cleaned)
            elif _TRIVIAL_TAG.match(text):
                cleaned = _clean_bullet(_TRIVIAL_TAG.sub('', text, count=1).strip())
                if cleaned and not _should_skip(cleaned):
                    trivial_bullets.append(cleaned)

        if suppress_entry:
            continue  # skip the whole entry

        bullets.extend(user_bullets)
        bullets.extend(trivial_bullets)

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
