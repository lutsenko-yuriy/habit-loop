#!/usr/bin/env python3
"""lint.py — Flag raw numeric literals in EdgeInsets/SizedBox calls under
lib/ that should instead use an AppSpacing token (lib/theme/spacing.dart).

HAB-187 WU7/WU8 swept the codebase onto AppSpacing once; this is the
enforcement mechanism that stops a raw literal sneaking back in a future PR.
Mirrors scripts/changelog/lint.py's shape: a plain function CI can run.

Usage:
    python3 scripts/design_system/lint.py [--root <path>]

Exit codes:
    0  No raw spacing literals found.
    1  One or more raw spacing literals found — see stdout for file:line.

A deliberate, documented exception (a literal that must NOT be a token —
e.g. because rounding to the nearest AppSpacing value would visibly change
layout) is suppressed with a trailing comment on the same line:

    padding: EdgeInsets.symmetric(horizontal: 1), // spacing-lint: allow (reason)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_LITERAL_CALL_RE = re.compile(r"(?:EdgeInsets\.\w+|SizedBox)\s*\(([^()]*)\)")
_NUMBER_RE = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?![\w])")
_SUPPRESS_COMMENT = 'spacing-lint: allow'


def find_raw_spacing_literals(root: Path) -> list[tuple[str, int, str]]:
    """Return (relative_path, line_number, line_text) for each raw numeric
    literal found inside an `EdgeInsets.<ctor>(...)` or `SizedBox(...)` call
    under lib/, skipping any line carrying a `// spacing-lint: allow`
    suppression comment.

    Known limitation (lightweight regex scan, not an AST parse, per HAB-189's
    own recommendation): a call whose arguments contain a nested
    parenthesised expression (e.g. `SizedBox(height: someFunc(8))`) is not
    scanned at all — the non-nested `[^()]*` capture can't span an inner
    `(...)`. Revisit with `custom_lint` (an AST-aware analyzer plugin) if
    this proves to miss real cases in practice.
    """
    lib_dir = root / 'lib'
    if not lib_dir.exists():
        return []

    findings: list[tuple[str, int, str]] = []
    for dart_file in sorted(lib_dir.rglob('*.dart')):
        try:
            text = dart_file.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue

        lines = text.splitlines()
        rel = dart_file.relative_to(root).as_posix()

        for call_match in _LITERAL_CALL_RE.finditer(text):
            args = call_match.group(1)
            args_start = call_match.start(1)
            for number_match in _NUMBER_RE.finditer(args):
                offset = args_start + number_match.start()
                line_no = text.count('\n', 0, offset) + 1
                line_text = lines[line_no - 1] if 0 <= line_no - 1 < len(lines) else ''
                if _SUPPRESS_COMMENT in line_text:
                    continue
                findings.append((rel, line_no, line_text.strip()))

    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=None, help='Project root (default: auto-detected)')
    args = parser.parse_args(argv)

    root = Path(args.root) if args.root else Path(__file__).resolve().parents[2]
    findings = find_raw_spacing_literals(root)

    if findings:
        print(f'Found {len(findings)} raw numeric literal(s) in EdgeInsets/SizedBox calls under lib/:')
        for rel, line_no, line_text in findings:
            print(f'  {rel}:{line_no}: {line_text}')
        print()
        print('Use an AppSpacing token (lib/theme/spacing.dart) instead of a bare number.')
        print('A deliberate exception can be suppressed with a trailing `// spacing-lint: allow (reason)` comment.')
        return 1

    print('OK — no raw spacing literals found.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
