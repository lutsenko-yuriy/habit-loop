#!/usr/bin/env python3
"""check.py — Advisory dead-code detector for Habit Loop.

Runs all detectors in priority order and prints a report. Always exits 0
(never blocks CI or commits). Intended to be invoked via the /dead-code-check
skill or manually before shipping.

Usage:
    python3 scripts/dead_code/check.py [--root <path>]

    --root  Project root directory (default: auto-detected from script location)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _dart_files(root: Path, dirs: list[str], exclude_patterns: list[str] | None = None) -> list[Path]:
    """Collect all .dart files under the given subdirs, skipping exclusions."""
    result = []
    for d in dirs:
        target = root / d
        if not target.exists():
            continue
        for f in sorted(target.rglob('*.dart')):
            rel = f.relative_to(root).as_posix()
            if exclude_patterns and any(re.search(p, rel) for p in exclude_patterns):
                continue
            result.append(f)
    return result


def _read_texts(files: list[Path]) -> str:
    """Concatenate all file contents into a single string for fast searching."""
    parts = []
    for f in files:
        try:
            parts.append(f.read_text(encoding='utf-8'))
        except (OSError, UnicodeDecodeError):
            pass
    return '\n'.join(parts)


# ---------------------------------------------------------------------------
# Detector 1: Orphaned l10n keys
# ---------------------------------------------------------------------------
# Strategy: read app_en.arb as the canonical key list, skip @-prefixed metadata
# entries, then for each key search for `.keyName` (word-boundary) in all Dart
# files except the generated localizations files that define every key by
# construction.

_L10N_EXCLUDE = [
    r'^lib/l10n/app_localizations',  # abstract class + per-locale implementations
    r'^lib/l10n/generated/',
]


def detect_orphaned_l10n_keys(root: Path) -> list[str]:
    """Return l10n keys from app_en.arb with no dot-reference in non-generated Dart files."""
    arb_path = root / 'lib' / 'l10n' / 'app_en.arb'
    if not arb_path.exists():
        return []

    with arb_path.open(encoding='utf-8') as fh:
        arb = json.load(fh)

    keys = [k for k in arb if not k.startswith('@')]
    if not keys:
        return []

    dart_files = _dart_files(root, ['lib', 'test', 'integration_test'], _L10N_EXCLUDE)
    combined = _read_texts(dart_files)

    orphans = []
    for key in keys:
        # Match `.keyName` followed by a non-word character (or end of string)
        # to avoid matching `.keyNameSuffix` as a reference to `keyName`.
        pattern = r'\.' + re.escape(key) + r'(?!\w)'
        if not re.search(pattern, combined):
            orphans.append(key)

    return orphans


# ---------------------------------------------------------------------------
# Detector 2: Orphaned analytics event classes
# ---------------------------------------------------------------------------
# Strategy: enumerate all classes extending AnalyticsEvent under
# lib/slices/*/analytics/*.dart. For each class, search lib/**/*.dart excluding
# the definition file. References in test/ and integration_test/ don't count —
# the class must be instantiated in production lib/ code to be considered live.

_ANALYTICS_GLOB = 'lib/slices/*/analytics/*.dart'
_ANALYTICS_CLASS_RE = re.compile(r'\bfinal\s+class\s+(\w+)\s+extends\s+AnalyticsEvent\b')


def detect_orphaned_analytics_events(root: Path) -> list[str]:
    """Return analytics event class names with no reference in lib/ outside their definition file."""
    analytics_files = sorted(root.glob(_ANALYTICS_GLOB))
    if not analytics_files:
        return []

    lib_dart_files = _dart_files(root, ['lib'])

    orphans = []
    for def_file in analytics_files:
        source = def_file.read_text(encoding='utf-8')
        for class_name in _ANALYTICS_CLASS_RE.findall(source):
            pattern = re.compile(r'\b' + re.escape(class_name) + r'\b')
            found = False
            for lib_file in lib_dart_files:
                if lib_file == def_file:
                    continue
                try:
                    if pattern.search(lib_file.read_text(encoding='utf-8')):
                        found = True
                        break
                except (OSError, UnicodeDecodeError):
                    pass
            if not found:
                orphans.append(class_name)

    return orphans


# ---------------------------------------------------------------------------
# Detector 3: Orphaned test files
# ---------------------------------------------------------------------------
# Strategy: scan test/ and integration_test/ for .dart files. Extract
# `package:habit_loop/` imports and resolve them to lib/ paths on disk.
#
# High-confidence: ALL package:habit_loop imports point to non-existent files
# → the file exclusively tested a removed feature.
#
# Informational: ZERO package:habit_loop imports → no production linkage
# detectable; flag for manual inspection.

_PACKAGE_IMPORT_RE = re.compile(r"import\s+'package:habit_loop/([^']+)'")


def detect_orphaned_test_files(root: Path) -> tuple[list[str], list[str]]:
    """Return (high_confidence, informational) lists of relative test file paths."""
    test_files = _dart_files(root, ['test', 'integration_test'])
    high: list[str] = []
    info: list[str] = []

    for test_file in test_files:
        try:
            source = test_file.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue

        imports = _PACKAGE_IMPORT_RE.findall(source)
        rel = test_file.relative_to(root).as_posix()

        if not imports:
            info.append(rel)
            continue

        if all(not (root / 'lib' / imp).exists() for imp in imports):
            high.append(rel)

    return high, info


# ---------------------------------------------------------------------------
# Detector 4: Orphaned handlers
# ---------------------------------------------------------------------------
# Two sub-checks:
#
# 1. Handler files: all *_handler.dart files under lib/ whose
#    package:habit_loop/ import path appears in no other .dart file.
#
# 2. vm:entry-point pragmas: top-level @pragma('vm:entry-point') functions
#    anywhere in lib/ that are not referenced by name in
#    flutter_local_notification_service.dart (the file that registers them).

_HANDLER_GLOB = 'lib/**/*_handler.dart'
_ENTRY_POINT_RE = re.compile(
    r"@pragma\('vm:entry-point'\)\s+(?:\w[\w<>?]*\s+)+([a-z]\w*)\s*\("
)
_NOTIFICATION_SERVICE_PATH = (
    'lib/infrastructure/notifications/data/flutter_local_notification_service.dart'
)


def detect_orphaned_handlers(root: Path) -> tuple[list[str], list[str]]:
    """Return (orphaned_handler_files, orphaned_entry_point_names)."""
    orphaned_files: list[str] = []
    orphaned_entry_points: list[str] = []

    # Sub-check 1: handler files with no importers
    handler_files = sorted(root.glob(_HANDLER_GLOB))
    if handler_files:
        handler_set = set(handler_files)
        other_dart = [f for f in _dart_files(root, ['lib', 'test', 'integration_test']) if f not in handler_set]
        combined = _read_texts(other_dart)
        for handler in handler_files:
            rel = handler.relative_to(root / 'lib').as_posix()
            if f'package:habit_loop/{rel}' not in combined:
                orphaned_files.append(handler.relative_to(root).as_posix())

    # Sub-check 2: vm:entry-point functions not wired in notification service
    ns_path = root / _NOTIFICATION_SERVICE_PATH
    try:
        ns_text = ns_path.read_text(encoding='utf-8') if ns_path.exists() else ''
    except (OSError, UnicodeDecodeError):
        ns_text = ''

    for lib_file in _dart_files(root, ['lib']):
        try:
            source = lib_file.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for fn_name in _ENTRY_POINT_RE.findall(source):
            if not re.search(r'\b' + re.escape(fn_name) + r'\b', ns_text):
                orphaned_entry_points.append(fn_name)

    return orphaned_files, orphaned_entry_points


# ---------------------------------------------------------------------------
# Report helpers
# ---------------------------------------------------------------------------

def _print_section(title: str, items: list[str], item_prefix: str = '  - ') -> None:
    if not items:
        print(f'[OK]   {title}: no orphans found.')
    else:
        print(f'[WARN] {title}: {len(items)} orphan(s) found')
        for item in sorted(items):
            print(f'{item_prefix}{item}')


def _print_handler_section(files: list[str], entry_points: list[str]) -> None:
    title = 'Orphaned handlers'
    if not files and not entry_points:
        print(f'[OK]   {title}: no orphans found.')
        return
    print(f'[WARN] {title}: {len(files) + len(entry_points)} item(s) flagged')
    if files:
        print('  Handler files with no importers:')
        for f in sorted(files):
            print(f'    - {f}')
    if entry_points:
        print('  @pragma(vm:entry-point) functions not wired in notification service:')
        for fn in sorted(entry_points):
            print(f'    - {fn}')


def _print_test_section(high: list[str], info: list[str]) -> None:
    title = 'Orphaned test files'
    if not high and not info:
        print(f'[OK]   {title}: no orphans found.')
        return
    print(f'[WARN] {title}: {len(high) + len(info)} file(s) flagged')
    if high:
        print('  High-confidence (all package:habit_loop imports missing):')
        for f in sorted(high):
            print(f'    - {f}')
    if info:
        print('  Informational (no package:habit_loop imports):')
        for f in sorted(info):
            print(f'    - {f}')


# ---------------------------------------------------------------------------
# Main runner
# ---------------------------------------------------------------------------

def run(root: Path) -> None:
    print('Dead-code check — advisory report')
    print('=' * 50)
    print()

    _print_section('L10n keys', detect_orphaned_l10n_keys(root))
    print()
    _print_section('Analytics events', detect_orphaned_analytics_events(root))
    print()
    _print_test_section(*detect_orphaned_test_files(root))
    print()
    _print_handler_section(*detect_orphaned_handlers(root))
    print()

    print('Done. This report is advisory — review findings before acting.')


def main() -> None:
    parser = argparse.ArgumentParser(description='Advisory dead-code detector for Habit Loop')
    parser.add_argument('--root', default=None, help='Project root directory')
    args = parser.parse_args()

    if args.root:
        root = Path(args.root).resolve()
    else:
        root = Path(__file__).resolve().parent.parent.parent

    if not (root / 'pubspec.yaml').exists():
        print(f'Error: {root} does not look like a Flutter project root (no pubspec.yaml)',
              file=sys.stderr)
        sys.exit(1)

    run(root)


if __name__ == '__main__':
    main()
