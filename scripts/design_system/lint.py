#!/usr/bin/env python3
"""lint.py — Flag raw numeric literals in EdgeInsets/SizedBox calls under
lib/ that should instead use an AppSpacing token (lib/theme/spacing.dart).

HAB-187 WU7/WU8 swept the codebase onto AppSpacing once; this is the
enforcement mechanism that stops a raw literal sneaking back in a future PR.
Mirrors scripts/changelog/lint.py's shape: a plain function CI can run.

Usage:
    python3 scripts/design_system/lint.py [--root <path>]

Exit codes:
    0  No raw spacing literals found (beyond the checked-in allowlist), and
       every allowlist entry still matches a real literal.
    1  One or more raw spacing literals found — see stdout for file:line.
    1  One or more allowlist entries are stale (no matching literal at that
       line any more) — see stdout for file:line.
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
_TYPOGRAPHY_ALLOWLIST_PATH = Path(__file__).with_name('typography_allowlist.txt')
_TYPOGRAPHY_TOKENS_REL_PATH = 'lib/theme/typography.dart'

# Word-boundary-guarded so `AnimatedSizedBox(` or `someEdgeInsets.all(` don't
# match. Covers named constructors (`SizedBox.square(`, `SizedBox.fromSize(`)
# and `EdgeInsetsDirectional`, both of which bypassed the gate entirely in an
# earlier version (2nd-pass PR #387 audit finding).
_CALL_START_RE = re.compile(r"\b(?:EdgeInsets(?:Directional)?\.\w+|SizedBox(?:\.\w+)?)\s*\(")
_NUMBER_RE = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?![\w])")

# Matches (and blanks out, preserving length/newlines) comments and string
# literals — `//` line comments, `/* */` block comments, and single/double
# -quoted strings (raw or not, single-line or triple-quoted) — before any
# scanning happens. Without this, a dartdoc comment or string that mentions a
# call shape is mistaken for a real one, and — since block comments weren't
# masked in an earlier version — an unbalanced paren inside a `/* ... */`
# prose comment could desync the balanced-paren walk in `_top_level_args`
# below, silently hiding real violations or misfiring on unrelated code
# (1st- and 2nd-pass PR #387 audit findings).
_STRING_OR_COMMENT_RE = re.compile(
    r"//[^\n]*"
    r"|/\*.*?\*/"
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
    for a literal passed directly to *this* call (1st-pass PR #387 audit
    finding: the original `[^()]*` non-nested regex went too far the other
    way and missed real top-level literals whenever a call had *any* nested
    parens at all, e.g. `SizedBox(width: 44, child: CustomPaint(...))`).
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


def _scan(root: Path) -> list[tuple[str, int, str]]:
    """Every raw numeric literal passed directly (not nested inside another
    call) to an `EdgeInsets(Directional).<ctor>(...)` or
    `SizedBox(.<ctor>)?(...)` call under lib/ — unfiltered by any allowlist.
    Shared by find_raw_spacing_literals and find_unused_allowlist_entries so
    both agree on exactly what counts as "a real literal at this location".
    """
    # Deliberately permissive here (empty result, not an error) — this is a
    # library function. The CLI's fail-loud guard for a missing lib/ lives in
    # main(), the sole current entry point; a future direct importer of this
    # module should add its own guard rather than rely on this one.
    lib_dir = root / 'lib'
    if not lib_dir.exists():
        return []

    all_literals: list[tuple[str, int, str]] = []
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
                line_text = lines[line_no - 1] if 0 <= line_no - 1 < len(lines) else ''
                all_literals.append((rel, line_no, line_text.strip()))

    return all_literals


def find_raw_spacing_literals(root: Path, allowlist: set[tuple[str, int]] | None = None) -> list[tuple[str, int, str]]:
    """Return (relative_path, line_number, line_text) for each raw numeric
    literal found by `_scan`, skipping any (path, line) pair present in
    `allowlist` (defaults to the checked-in spacing_allowlist.txt).
    """
    if allowlist is None:
        allowlist = load_allowlist()
    return [f for f in _scan(root) if (f[0], f[1]) not in allowlist]


def find_unused_allowlist_entries(root: Path, allowlist: set[tuple[str, int]] | None = None) -> set[tuple[str, int]]:
    """Return the subset of `allowlist` (defaults to the checked-in
    spacing_allowlist.txt) that does not match any real literal found by
    `_scan` — a stale entry (the literal was removed, tokenized, or the file
    doesn't exist any more) that would otherwise silently become a permanent
    blanket exemption on that line number (2nd-pass PR #387 audit finding).
    """
    if allowlist is None:
        allowlist = load_allowlist()
    found = {(f[0], f[1]) for f in _scan(root)}
    return allowlist - found


# Word-boundary-guarded so a widening match like `MyTextStyle(` doesn't fire.
_TEXTSTYLE_CALL_RE = re.compile(r"\bTextStyle\s*\(")

# Parses one `static const TextStyle <name> = TextStyle(...)` token
# definition out of lib/theme/typography.dart.
_TYPOGRAPHY_TOKEN_DEF_RE = re.compile(r"static const TextStyle (\w+) = TextStyle\s*\(")

# The properties that determine a TextStyle's rendered identity for
# duplicate-detection purposes. `color` is deliberately excluded — per
# AppTypography's own doc comment, tokens never carry a color; call sites
# apply it via `.copyWith(color: ...)`, so it's irrelevant to whether a
# literal duplicates a token.
_TYPOGRAPHY_PROPERTY_RE = re.compile(
    r"\b(fontSize|fontWeight|fontStyle|letterSpacing|height|fontFamily)\s*:\s*([^,]+)"
)


def _typography_signature(args_text: str) -> frozenset[tuple[str, str]]:
    """Reduce a `TextStyle(...)` call's argument text to the subset of
    properties that determine its rendered identity, normalizing numeric
    literals (`22` vs `22.0`) so equivalent values compare equal."""
    sig: set[tuple[str, str]] = set()
    for match in _TYPOGRAPHY_PROPERTY_RE.finditer(args_text):
        key = match.group(1)
        value = match.group(2).strip()
        if re.fullmatch(r'\d+(?:\.\d+)?', value):
            value = str(float(value))
        sig.add((key, value))
    return frozenset(sig)


def _extract_typography_tokens(root: Path) -> dict[frozenset[tuple[str, str]], str]:
    """Parse lib/theme/typography.dart's own `AppTypography` token
    definitions into a signature -> token-name mapping. Missing file (or a
    token with no identity properties, e.g. none) contributes nothing —
    not an error, since a project without this file simply has no
    typography tokens to duplicate."""
    tokens_path = root / _TYPOGRAPHY_TOKENS_REL_PATH
    if not tokens_path.exists():
        return {}

    try:
        text = tokens_path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return {}

    masked = _mask(text)
    tokens: dict[frozenset[tuple[str, str]], str] = {}
    for match in _TYPOGRAPHY_TOKEN_DEF_RE.finditer(masked):
        name = match.group(1)
        args = _top_level_args(masked, match.end())
        sig = _typography_signature(args)
        if sig:
            tokens[sig] = name
    return tokens


def _scan_typography(root: Path) -> list[tuple[str, int, str, str]]:
    """Every `TextStyle(...)` call under lib/ (excluding
    lib/theme/typography.dart's own token definitions) whose properties
    exactly duplicate an AppTypography token's — unfiltered by any
    allowlist. Shared by find_typography_token_matches and
    find_unused_typography_allowlist_entries so both agree on exactly what
    counts as "a real duplicate at this location"."""
    lib_dir = root / 'lib'
    if not lib_dir.exists():
        return []

    tokens = _extract_typography_tokens(root)
    if not tokens:
        return []

    all_matches: list[tuple[str, int, str, str]] = []
    for dart_file in sorted(lib_dir.rglob('*.dart')):
        rel = dart_file.relative_to(root).as_posix()
        if rel == _TYPOGRAPHY_TOKENS_REL_PATH:
            continue

        try:
            text = dart_file.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue

        masked = _mask(text)
        lines = text.splitlines()

        for call_match in _TEXTSTYLE_CALL_RE.finditer(masked):
            args = _top_level_args(masked, call_match.end())
            sig = _typography_signature(args)
            token_name = tokens.get(sig)
            if token_name is None:
                continue
            line_no = text.count('\n', 0, call_match.start()) + 1
            line_text = lines[line_no - 1] if 0 <= line_no - 1 < len(lines) else ''
            all_matches.append((rel, line_no, line_text.strip(), token_name))

    return all_matches


def find_typography_token_matches(
    root: Path, allowlist: set[tuple[str, int]] | None = None
) -> list[tuple[str, int, str, str]]:
    """Return (relative_path, line_number, line_text, token_name) for each
    raw `TextStyle(...)` call found by `_scan_typography` that exactly
    duplicates an AppTypography token, skipping any (path, line) pair
    present in `allowlist` (defaults to the checked-in
    typography_allowlist.txt)."""
    if allowlist is None:
        allowlist = load_allowlist(_TYPOGRAPHY_ALLOWLIST_PATH)
    return [f for f in _scan_typography(root) if (f[0], f[1]) not in allowlist]


def find_unused_typography_allowlist_entries(
    root: Path, allowlist: set[tuple[str, int]] | None = None
) -> set[tuple[str, int]]:
    """Return the subset of `allowlist` (defaults to the checked-in
    typography_allowlist.txt) that does not match any real duplicate found
    by `_scan_typography` — a stale entry that would otherwise silently
    become a permanent blanket exemption on that line number."""
    if allowlist is None:
        allowlist = load_allowlist(_TYPOGRAPHY_ALLOWLIST_PATH)
    found = {(f[0], f[1]) for f in _scan_typography(root)}
    return allowlist - found


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=None, help='Project root (default: auto-detected)')
    args = parser.parse_args(argv)

    root = Path(args.root) if args.root else Path(__file__).resolve().parents[2]

    if not (root / 'lib').exists():
        print(f'Error: {root} has no lib/ directory — wrong --root, or run from the repo root.', file=sys.stderr)
        return 1

    allowlist = load_allowlist()
    findings = find_raw_spacing_literals(root, allowlist)
    unused = find_unused_allowlist_entries(root, allowlist)
    ok = True

    if findings:
        ok = False
        print(f'Found {len(findings)} raw numeric literal(s) in EdgeInsets/SizedBox calls under lib/:')
        for rel, line_no, line_text in findings:
            print(f'  {rel}:{line_no}: {line_text}')
        print()
        print('Use an AppSpacing token (lib/theme/spacing.dart) instead of a bare number.')
        print(f'A deliberate, fixed-dimension exception belongs in {_ALLOWLIST_PATH.name} (path:line, one per line).')

    if unused:
        ok = False
        if findings:
            print()
        print(f'{len(unused)} stale entr{"y" if len(unused) == 1 else "ies"} in {_ALLOWLIST_PATH.name} '
              '(no matching raw literal at that line any more — remove or update):')
        for rel, line_no in sorted(unused):
            print(f'  {rel}:{line_no}')

    typography_allowlist = load_allowlist(_TYPOGRAPHY_ALLOWLIST_PATH)
    typography_findings = find_typography_token_matches(root, typography_allowlist)
    typography_unused = find_unused_typography_allowlist_entries(root, typography_allowlist)

    if typography_findings:
        ok = False
        print()
        print(f'Found {len(typography_findings)} raw TextStyle literal(s) under lib/ that duplicate an '
              'AppTypography token:')
        for rel, line_no, line_text, token_name in typography_findings:
            print(f'  {rel}:{line_no}: {line_text}  (use AppTypography.{token_name})')
        print()
        print(f'A deliberate, one-off exception belongs in {_TYPOGRAPHY_ALLOWLIST_PATH.name} (path:line, one per '
              'line).')

    if typography_unused:
        ok = False
        print()
        print(f'{len(typography_unused)} stale entr{"y" if len(typography_unused) == 1 else "ies"} in '
              f'{_TYPOGRAPHY_ALLOWLIST_PATH.name} (no matching duplicate literal at that line any more — remove '
              'or update):')
        for rel, line_no in sorted(typography_unused):
            print(f'  {rel}:{line_no}')

    if not ok:
        return 1

    print('OK — no raw spacing or typography literals found.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
