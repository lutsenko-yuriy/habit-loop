#!/usr/bin/env python3
"""lint.py — Flag raw numeric literals in EdgeInsets/SizedBox calls under
lib/ that should instead use an AppSpacing token (lib/theme/spacing.dart).

HAB-187 WU7/WU8 swept the codebase onto AppSpacing once; this is the
enforcement mechanism that stops a raw literal sneaking back in a future PR.
Mirrors scripts/changelog/lint.py's shape: a plain function CI can run.

Usage:
    python3 scripts/design_system/lint.py [--root <path>]

Exit codes:
    0  No raw spacing literals found (beyond the checked-in allowlist).
    1  One or more raw spacing literals found — see stdout for file:line.
    1  --root does not contain a lib/ directory (fails loud, not open — a
       wrong/missing root must not read as a silent pass on a blocking gate).

A deliberate, documented exception (a literal that must NOT be a token —
e.g. because it's a fixed dimension, not a spacing gap, so no AppSpacing
value represents it correctly) is listed in spacing_allowlist.txt next to
this file, one "path:line" entry per line — not an inline code comment, to
keep application code free of lint-tooling noise.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_ALLOWLIST_PATH = Path(__file__).with_name('spacing_allowlist.txt')

# Word-boundary-guarded so `AnimatedSizedBox(` or `someEdgeInsets.all(` don't
# match (PR #387 audit finding).
_CALL_START_RE = re.compile(r"\b(?:EdgeInsets\.\w+|SizedBox)\s*\(")
_NUMBER_RE = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?![\w])")

# Matches (and blanks out, preserving length/newlines) line comments and
# string literals — single- and double-quoted, raw or not, single-line or
# triple-quoted — before any scanning happens. Without this, a dartdoc
# comment that documents the rule itself (e.g. `/// Uses EdgeInsets.all(16)`)
# or a string literal containing similar text is mistaken for a real call
# (PR #387 audit finding).
_STRING_OR_COMMENT_RE = re.compile(
    r"//[^\n]*"
    r"|r?'''(?:[^\\]|\\.)*?'''"
    r"|r?\"\"\"(?:[^\\]|\\.)*?\"\"\""
    r"|r?\"(?:[^\"\\\n]|\\.)*\""
    r"|r?'(?:[^'\\\n]|\\.)*'",
    re.DOTALL,
)


def _mask(text: str) -> str:
    """Blank out comment/string contents, keeping every other character
    (including newlines, to keep line numbers correct) in place."""

    def _blank(match: re.Match) -> str:
        return ''.join(ch if ch == '\n' else ' ' for ch in match.group(0))

    return _STRING_OR_COMMENT_RE.sub(_blank, text)


def _top_level_args(masked_text: str, call_end: int) -> str:
    """Return the call's own argument text starting right after its opening
    `(` at `call_end`, with any nested sub-call's parenthesised contents
    (and their delimiting parens) blanked out — so a number buried two-plus
    levels deep inside an unrelated nested call/constructor is not mistaken
    for a literal passed directly to *this* call (PR #387 audit finding: the
    original `[^()]*` non-nested regex went too far the other way and missed
    real top-level literals whenever a call had *any* nested parens at all,
    e.g. `SizedBox(width: 44, child: CustomPaint(...))`).
    """
    depth = 1
    chars: list[str] = []
    i = call_end
    while i < len(masked_text):
        ch = masked_text[i]
        depth_before = depth
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                break
        if max(depth_before, depth) >= 2:
            chars.append(ch if ch == '\n' else ' ')
        else:
            chars.append(ch)
        i += 1
    return ''.join(chars)


def load_allowlist(path: Path = _ALLOWLIST_PATH) -> set[tuple[str, int]]:
    """Parse spacing_allowlist.txt into a set of (relative_path, line_number)
    pairs. Missing file → empty set (nothing allowlisted, not an error)."""
    if not path.exists():
        return set()

    entries: set[tuple[str, int]] = set()
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        line = raw_line.split('#', 1)[0].strip()
        if not line:
            continue
        rel_path, _, line_no = line.rpartition(':')
        if not rel_path or not line_no.isdigit():
            continue
        entries.add((rel_path, int(line_no)))
    return entries


def find_raw_spacing_literals(root: Path, allowlist: set[tuple[str, int]] | None = None) -> list[tuple[str, int, str]]:
    """Return (relative_path, line_number, line_text) for each raw numeric
    literal passed directly (not nested inside another call) to an
    `EdgeInsets.<ctor>(...)` or `SizedBox(...)` call under lib/, skipping any
    (path, line) pair present in `allowlist` (defaults to the checked-in
    spacing_allowlist.txt next to this module).
    """
    if allowlist is None:
        allowlist = load_allowlist()

    lib_dir = root / 'lib'
    if not lib_dir.exists():
        return []

    findings: list[tuple[str, int, str]] = []
    for dart_file in sorted(lib_dir.rglob('*.dart')):
        try:
            text = dart_file.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue

        masked = _mask(text)
        lines = text.splitlines()
        rel = dart_file.relative_to(root).as_posix()

        for call_match in _CALL_START_RE.finditer(masked):
            args = _top_level_args(masked, call_match.end())
            args_start = call_match.end()
            for number_match in _NUMBER_RE.finditer(args):
                offset = args_start + number_match.start()
                line_no = text.count('\n', 0, offset) + 1
                if (rel, line_no) in allowlist:
                    continue
                line_text = lines[line_no - 1] if 0 <= line_no - 1 < len(lines) else ''
                findings.append((rel, line_no, line_text.strip()))

    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=None, help='Project root (default: auto-detected)')
    args = parser.parse_args(argv)

    root = Path(args.root) if args.root else Path(__file__).resolve().parents[2]

    if not (root / 'lib').exists():
        print(f'Error: {root} has no lib/ directory — wrong --root, or run from the repo root.', file=sys.stderr)
        return 1

    findings = find_raw_spacing_literals(root)

    if findings:
        print(f'Found {len(findings)} raw numeric literal(s) in EdgeInsets/SizedBox calls under lib/:')
        for rel, line_no, line_text in findings:
            print(f'  {rel}:{line_no}: {line_text}')
        print()
        print('Use an AppSpacing token (lib/theme/spacing.dart) instead of a bare number.')
        print(f'A deliberate, fixed-dimension exception belongs in {_ALLOWLIST_PATH.name} (path:line, one per line).')
        return 1

    print('OK — no raw spacing literals found.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
