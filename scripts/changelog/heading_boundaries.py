"""heading_boundaries.py — Shared body-boundary helper for CHANGELOG.md parsers.

Every `## [X.Y.Z]` entry's "body" is the text between its own heading and the
next heading in the file. Historically each parser (distribute.py,
release_notes.py, lint.py) computed that boundary using only numbered
`## [X.Y.Z]` headings — which silently merges a sealed `## [Unreleased]`
section sitting between two numbered releases into the *newer* release's
body (HAB-185). This module finds boundaries using *any* `## [...]` heading
(numeric or `Unreleased`), so a sealed Unreleased batch is never absorbed
into an adjacent numbered entry.
"""

from __future__ import annotations

import re

_ANY_HEADING = re.compile(r'^## \[.+?\]', re.MULTILINE)


def heading_starts(content: str) -> list[int]:
    """Return the start offsets of every '## [...]' heading (numeric or
    Unreleased), in file order."""
    return [m.start() for m in _ANY_HEADING.finditer(content)]


def body_end_for(heading_start: int, all_heading_starts: list[int], content_len: int) -> int:
    """Given a heading's own start offset, return where its body ends: the
    start of the next heading of any kind after it, or end-of-content."""
    for pos in all_heading_starts:
        if pos > heading_start:
            return pos
    return content_len
