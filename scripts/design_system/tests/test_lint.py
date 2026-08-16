from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from design_system.lint import find_raw_spacing_literals, find_unused_allowlist_entries, load_allowlist


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

    def _scan(self, root: Path, allowlist: set[tuple[str, int]] | None = None) -> list[tuple[str, int, str]]:
        """Scan with an explicit (default empty) allowlist so tests never
        depend on the real checked-in spacing_allowlist.txt."""
        return find_raw_spacing_literals(root, allowlist=allowlist or set())

    def test_raw_literal_in_edge_insets_flagged(self):
        root = self._project(
            {'lib/foo.dart': "Padding(padding: EdgeInsets.all(16));"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][0], 'lib/foo.dart')

    def test_raw_literal_in_sized_box_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: 8);"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)

    def test_app_spacing_token_not_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: AppSpacing.s16);"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_multiple_literals_in_one_call_all_flagged(self):
        root = self._project(
            {'lib/foo.dart': "EdgeInsets.symmetric(horizontal: 8, vertical: 4);"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 2)

    def test_decimal_literal_flagged(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(width: 8.0);"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)

    def test_allowlisted_line_exempted(self):
        root = self._project(
            {'lib/foo.dart': "Padding(padding: EdgeInsets.symmetric(horizontal: 1));"},
        )
        findings = self._scan(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(findings, [])

    def test_allowlist_is_per_line_not_per_file(self):
        """A file can have both an allowlisted literal and a real violation
        — only the listed line is exempted."""
        root = self._project(
            {
                'lib/foo.dart': (
                    "Padding(padding: EdgeInsets.symmetric(horizontal: 1));\n"
                    "SizedBox(height: 8);\n"
                )
            },
        )
        findings = self._scan(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][1], 2)

    def test_no_matches_returns_empty_list(self):
        root = self._project(
            {'lib/foo.dart': "class Foo {}"},
        )
        findings = self._scan(root)
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
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0][1], 3)

    def test_literal_nested_inside_unrelated_call_not_flagged(self):
        """A literal passed to an unrelated nested function call (not
        directly to SizedBox/EdgeInsets itself) is not a spacing literal for
        *this* call and must not be flagged."""
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: computeHeight(8));"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_top_level_literal_alongside_nested_call_is_flagged(self):
        """PR #387 audit finding: the original non-nested regex silently
        missed a real top-level literal whenever the call had *any* nested
        parens elsewhere in its args (e.g. a `child:` widget). Balanced-paren
        tracking must still find the sibling literal."""
        root = self._project(
            {'lib/foo.dart': "SizedBox(width: 44, child: CustomPaint(painter: MyPainter()));"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)
        self.assertIn('44', findings[0][2])

    def test_dartdoc_comment_mentioning_a_call_not_flagged(self):
        """PR #387 audit finding: documenting the rule itself (or any prior
        API usage) in a comment must not trigger the lint on the comment."""
        root = self._project(
            {'lib/foo.dart': "/// Uses EdgeInsets.all(16) for outer padding.\nclass Foo {}"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_line_comment_after_call_not_double_counted_as_new_call(self):
        root = self._project(
            {'lib/foo.dart': "SizedBox(height: AppSpacing.s8); // was EdgeInsets.all(16) before HAB-187"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_string_literal_mentioning_a_call_not_flagged(self):
        """PR #387 audit finding: a string literal containing text that
        looks like a call must not trigger the lint."""
        root = self._project(
            {'lib/foo.dart': "final s = 'example: SizedBox(height: 16)';"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_subclass_name_not_matched_by_word_boundary(self):
        """PR #387 audit finding: SizedBox had no left word boundary, so
        AnimatedSizedBox( would falsely match."""
        root = self._project(
            {'lib/foo.dart': "AnimatedSizedBox(height: 8);"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_only_scans_lib_directory(self):
        root = self._project(
            {'test/foo_test.dart': "SizedBox(height: 8);"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_block_comment_masked(self):
        """2nd-pass audit finding: /* ... */ comments were not masked at
        all, so an unbalanced paren inside one (e.g. mentioning "foo)" in
        prose) could desync the balanced-paren walk and either hide a real
        violation or misfire on unrelated code."""
        root = self._project(
            {
                'lib/foo.dart': (
                    "Widget a() => SizedBox(\n"
                    "  /* note: see foo) below */\n"
                    "  width: 44,\n"
                    "  height: 44,\n"
                    ");\n"
                )
            },
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 2)

    def test_multiline_block_comment_masked(self):
        root = self._project(
            {'lib/foo.dart': "/*\n * Uses EdgeInsets.all(16) for outer padding.\n */\nclass Foo {}"},
        )
        findings = self._scan(root)
        self.assertEqual(findings, [])

    def test_sized_box_named_constructor_flagged(self):
        """2nd-pass audit finding: SizedBox.square/.fromSize bypassed the
        gate entirely since only bare SizedBox( was matched."""
        root = self._project(
            {'lib/foo.dart': "SizedBox.square(dimension: 44);"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)

    def test_edge_insets_directional_flagged(self):
        """2nd-pass audit finding: EdgeInsetsDirectional bypassed the gate
        entirely since only EdgeInsets.<ctor>( was matched."""
        root = self._project(
            {'lib/foo.dart': "EdgeInsetsDirectional.only(start: 12);"},
        )
        findings = self._scan(root)
        self.assertEqual(len(findings), 1)


class TestFindUnusedAllowlistEntries(unittest.TestCase):

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

    def test_entry_matching_a_real_literal_is_not_unused(self):
        root = self._project(
            {'lib/foo.dart': "Padding(padding: EdgeInsets.symmetric(horizontal: 1));"},
        )
        unused = find_unused_allowlist_entries(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(unused, set())

    def test_entry_with_no_matching_literal_is_unused(self):
        """2nd-pass audit finding: a stale allowlist entry (the literal at
        that line was removed or already tokenized) must be detectable,
        not silently become a permanent blanket exemption on that line."""
        root = self._project(
            {'lib/foo.dart': "Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.s2));"},
        )
        unused = find_unused_allowlist_entries(root, allowlist={('lib/foo.dart', 1)})
        self.assertEqual(unused, {('lib/foo.dart', 1)})

    def test_entry_for_nonexistent_file_is_unused(self):
        root = self._project({})
        unused = find_unused_allowlist_entries(root, allowlist={('lib/gone.dart', 1)})
        self.assertEqual(unused, {('lib/gone.dart', 1)})


class TestLoadAllowlist(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _write(self, content: str) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        path = root / 'allowlist.txt'
        path.write_text(content)
        return path

    def test_missing_file_returns_empty_set(self):
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        self.assertEqual(load_allowlist(root / 'does_not_exist.txt'), set())

    def test_parses_path_colon_line_entries(self):
        path = self._write('lib/a.dart:12\nlib/b.dart:34\n')
        self.assertEqual(load_allowlist(path), {('lib/a.dart', 12), ('lib/b.dart', 34)})

    def test_comments_and_blank_lines_ignored(self):
        path = self._write('# a comment\n\nlib/a.dart:5  # trailing note\n')
        self.assertEqual(load_allowlist(path), {('lib/a.dart', 5)})

    def test_malformed_line_ignored_not_crashed(self):
        path = self._write('not-a-valid-entry\nlib/a.dart:notanumber\nlib/b.dart:7\n')
        self.assertEqual(load_allowlist(path), {('lib/b.dart', 7)})


class TestMain(unittest.TestCase):

    def test_missing_lib_dir_fails_loud_not_silent_pass(self):
        """PR #387 audit finding: a wrong/missing --root must not read as a
        silent pass on a blocking CI gate."""
        from design_system.lint import main

        empty_root = Path(tempfile.mkdtemp())
        try:
            self.assertEqual(main(['--root', str(empty_root)]), 1)
        finally:
            shutil.rmtree(empty_root, ignore_errors=True)
