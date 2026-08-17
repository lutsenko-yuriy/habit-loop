from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from design_system.lint import find_typography_token_matches, find_unused_typography_allowlist_entries

_TOKENS_FILE = (
    "abstract final class AppTypography {\n"
    "  static const TextStyle emphasis = TextStyle(fontWeight: FontWeight.w600);\n"
    "  static const TextStyle dateCaption = TextStyle(fontSize: 12, fontStyle: FontStyle.italic);\n"
    "  static const TextStyle wizardStepTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);\n"
    "  static const TextStyle body = TextStyle(fontSize: 14);\n"
    "}\n"
)


class TestFindTypographyTokenMatches(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, lib_files: dict[str, str], include_tokens: bool = True) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        files = dict(lib_files)
        if include_tokens:
            files['lib/theme/typography.dart'] = _TOKENS_FILE
        for rel_path, content in files.items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        return root

    def _scan(self, root: Path, allowlist: set[tuple[str, int]] | None = None) -> list[tuple[str, int, str, str]]:
        return find_typography_token_matches(root, allowlist=allowlist or set())

    def test_literal_matching_token_exactly_is_flagged(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontWeight: FontWeight.w600));"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][3], 'AppTypography.emphasis')

    def test_literal_missing_a_token_property_not_flagged(self):
        """dateCaption is fontSize:12 + italic — a plain fontSize:12 with no
        fontStyle renders differently and must not be flagged."""
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 12));"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_literal_with_extra_identity_property_not_flagged(self):
        """body is fontSize:14 only — fontSize:14 plus a fontWeight the
        token doesn't carry is a different rendered style, not a duplicate."""
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_decimal_and_integer_font_size_treated_as_equal(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold));"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][3], 'AppTypography.wizardStepTitle')

    def test_genuinely_one_off_style_not_flagged(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 11, letterSpacing: 0.4));"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_token_definitions_file_itself_not_scanned(self):
        """Scanning must exclude lib/theme/typography.dart's own token
        definitions, or every token would flag itself as a duplicate."""
        root = self._project({})
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_no_typography_file_yields_no_tokens_and_no_findings(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontWeight: FontWeight.w600));"},
            include_tokens=False,
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_allowlisted_line_exempted(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontWeight: FontWeight.w600));"},
        )
        findings = self._scan(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(findings, [])

    def test_multiline_call_reports_correct_line_number(self):
        root = self._project(
            {
                'lib/foo.dart': (
                    "final style = TextStyle(\n"
                    "  fontWeight: FontWeight.w600,\n"
                    ");\n"
                )
            },
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][1], 1)

    def test_string_literal_mentioning_textstyle_not_flagged(self):
        root = self._project(
            {'lib/foo.dart': "final s = 'example: TextStyle(fontWeight: FontWeight.w600)';"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_non_identity_property_beyond_color_prevents_a_false_match(self):
        """Audit finding (PR #392): an earlier version only compared a fixed
        shortlist of properties, so a literal that added e.g. `shadows:`
        alongside a matching fontSize was false-flagged as a duplicate of
        `body` even though it renders differently. Every property except
        `color` must count, not just the shortlisted ones."""
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 14, wordSpacing: 2));"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_color_property_still_ignored_when_matching(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 14, color: Colors.red));"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][3], 'AppTypography.body')

    def test_colliding_token_signatures_both_reported_not_silently_dropped(self):
        """Audit finding (PR #392): a dict keyed by signature with
        last-write-wins silently dropped one of two tokens sharing a
        signature from the map — a duplicate literal was then pointed at
        the wrong (or a missing) replacement. Both names must survive."""
        root = self._project(
            {
                'lib/theme/typography.dart': (
                    "abstract final class AppTypography {\n"
                    "  static const TextStyle sectionTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);\n"
                    "  static const TextStyle wizardStepTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);\n"
                    "}\n"
                ),
                'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));",
            },
            include_tokens=False,
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][3], 'AppTypography.sectionTitle or AppTypography.wizardStepTitle')

    def test_token_definition_wrapped_across_lines_still_parsed(self):
        """Audit finding (PR #392): the original regex required a literal
        space around `=`, so a dart-format line wrap between the token name
        and `TextStyle(` silently dropped the token from the map."""
        root = self._project(
            {
                'lib/theme/typography.dart': (
                    "abstract final class AppTypography {\n"
                    "  static const TextStyle veryLongTokenNameThatWraps =\n"
                    "      TextStyle(fontSize: 19, fontWeight: FontWeight.w500);\n"
                    "}\n"
                ),
                'lib/foo.dart': "Text('x', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500));",
            },
            include_tokens=False,
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][3], 'AppTypography.veryLongTokenNameThatWraps')


class TestFindUnusedTypographyAllowlistEntries(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, lib_files: dict[str, str]) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        files = dict(lib_files)
        files.setdefault('lib/theme/typography.dart', _TOKENS_FILE)
        for rel_path, content in files.items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        return root

    def test_entry_matching_a_real_duplicate_is_not_unused(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: const TextStyle(fontWeight: FontWeight.w600));"},
        )
        unused = find_unused_typography_allowlist_entries(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(unused, set())

    def test_entry_with_no_matching_duplicate_is_unused(self):
        root = self._project(
            {'lib/foo.dart': "Text('x', style: AppTypography.emphasis);"},
        )
        unused = find_unused_typography_allowlist_entries(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(unused, {('lib/foo.dart', 1)})


if __name__ == '__main__':
    unittest.main()
