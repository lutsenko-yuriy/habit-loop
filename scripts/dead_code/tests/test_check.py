import json
import shutil
import tempfile
import unittest
from pathlib import Path

from dead_code.check import detect_orphaned_l10n_keys


def _make_project(arb_keys: dict, dart_files: dict[str, str]) -> Path:
    """Create a minimal fake project tree and return its root path."""
    root = Path(tempfile.mkdtemp())
    (root / 'pubspec.yaml').write_text('name: habit_loop\n')
    l10n_dir = root / 'lib' / 'l10n'
    l10n_dir.mkdir(parents=True)
    (l10n_dir / 'app_en.arb').write_text(json.dumps(arb_keys))
    for rel_path, content in dart_files.items():
        f = root / rel_path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content)
    return root


class TestDetectOrphanedL10nKeys(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, arb_keys: dict, dart_files: dict[str, str]) -> Path:
        root = _make_project(arb_keys, dart_files)
        self._roots.append(root)
        return root

    def test_referenced_key_not_reported(self):
        root = self._project(
            {'appTitle': 'Habit Loop'},
            {'lib/some_widget.dart': 'final title = l10n.appTitle;'},
        )
        self.assertEqual(detect_orphaned_l10n_keys(root), [])

    def test_unreferenced_key_reported(self):
        root = self._project(
            {'orphanKey': 'Unused'},
            {'lib/some_widget.dart': 'final x = 1;'},
        )
        self.assertIn('orphanKey', detect_orphaned_l10n_keys(root))

    def test_metadata_at_keys_skipped(self):
        root = self._project(
            {'realKey': 'Hello', '@realKey': {'description': 'A greeting'}},
            {'lib/foo.dart': 'text(l10n.realKey)'},
        )
        orphans = detect_orphaned_l10n_keys(root)
        self.assertNotIn('@realKey', orphans)
        self.assertEqual(orphans, [])

    def test_reference_in_test_file_counts(self):
        root = self._project(
            {'testKey': 'Test value'},
            {'test/some_test.dart': "expect(l10n.testKey, 'Test value');"},
        )
        self.assertEqual(detect_orphaned_l10n_keys(root), [])

    def test_reference_in_integration_test_counts(self):
        root = self._project(
            {'someLabel': 'Label'},
            {'integration_test/scenario.dart': 'find.text(l10n.someLabel)'},
        )
        self.assertEqual(detect_orphaned_l10n_keys(root), [])

    def test_generated_localizations_file_excluded(self):
        """A key appearing only in app_localizations.dart is still orphaned."""
        root = self._project(
            {'onlyInGenerated': 'Value'},
            {'lib/l10n/app_localizations.dart': 'String get onlyInGenerated;'},
        )
        self.assertIn('onlyInGenerated', detect_orphaned_l10n_keys(root))

    def test_generated_locale_implementation_excluded(self):
        """A key appearing only in app_localizations_en.dart is still orphaned."""
        root = self._project(
            {'localeKey': 'Value'},
            {'lib/l10n/app_localizations_en.dart': "@override\nString get localeKey => 'Value';"},
        )
        self.assertIn('localeKey', detect_orphaned_l10n_keys(root))

    def test_missing_arb_file_returns_empty(self):
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        (root / 'pubspec.yaml').write_text('name: habit_loop\n')
        self.assertEqual(detect_orphaned_l10n_keys(root), [])

    def test_multiple_keys_mixed(self):
        root = self._project(
            {'usedKey': 'Used', 'orphanA': 'Orphan A', 'orphanB': 'Orphan B'},
            {'lib/ui.dart': 'text(l10n.usedKey)'},
        )
        orphans = detect_orphaned_l10n_keys(root)
        self.assertNotIn('usedKey', orphans)
        self.assertIn('orphanA', orphans)
        self.assertIn('orphanB', orphans)

    def test_partial_name_match_not_counted(self):
        """'.appTitleSuffix' must not count as a reference to 'appTitle'."""
        root = self._project(
            {'appTitle': 'Title'},
            {'lib/foo.dart': 'l10n.appTitleSuffix'},
        )
        self.assertIn('appTitle', detect_orphaned_l10n_keys(root))


if __name__ == '__main__':
    unittest.main()
