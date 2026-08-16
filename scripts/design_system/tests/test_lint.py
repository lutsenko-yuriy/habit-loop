from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from design_system.lint import find_raw_spacing_literals


class TestFindRawSpacingLiterals(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, lib_files: dict[str, str]) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        for rel_path, content in lib_files.items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        return root

    def test_raw_literal_in_edge_insets_flagged(self):
        root = self._project(
            {'lib/foo.dart': "Padding(padding: EdgeInsets.all(16));"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][0], 'lib/foo.dart')

    def test_raw_literal_in_sized_box_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: 8);"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(len(findings), 1)

    def test_app_spacing_token_not_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: AppSpacing.s16);"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(findings, [])

    def test_multiple_literals_in_one_call_all_flagged(self):
        root = self._project(
            {'lib/foo.dart': "EdgeInsets.symmetric(horizontal: 8, vertical: 4);"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(len(findings), 2)

    def test_decimal_literal_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(width: 8.0);"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(len(findings), 1)

    def test_suppression_comment_exempts_line(self):
        root = self._project(
            {
                'lib/foo.dart': (
                    "Padding(\n"
                    "  padding: EdgeInsets.symmetric(horizontal: 1), // spacing-lint: allow (doubling would break visuals)\n"
                    ");\n"
                )
            },
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(findings, [])

    def test_no_matches_returns_empty_list(self):
        root = self._project(
            {'lib/foo.dart': "class Foo {}"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(findings, [])

    def test_multiline_call_reports_correct_line_number(self):
        root = self._project(
            {
                'lib/foo.dart': (
                    "class Foo {\n"
                    "  Widget build() => SizedBox(\n"
                    "    height: 8,\n"
                    "  );\n"
                    "}\n"
                )
            },
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][1], 3)

    def test_nested_call_in_args_is_skipped_not_crashed(self):
        """Known limitation: a nested parenthesised expression inside the
        call args breaks the non-nested regex capture, so this raw literal
        is silently missed rather than flagged. Documented, not a crash."""
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: computeHeight(8));"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(findings, [])

    def test_only_scans_lib_directory(self):
        root = self._project(
            {'test/foo_test.dart': "SizedBox(height: 8);"},
        )
        findings = find_raw_spacing_literals(root)
        self.assertEqual(findings, [])
