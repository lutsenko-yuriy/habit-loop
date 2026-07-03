from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from dead_code.check import detect_orphaned_analytics_events, detect_orphaned_l10n_keys


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


def _make_analytics_project(analytics_files: dict[str, str], lib_files: dict[str, str] | None = None) -> Path:
    """Create a fake project with analytics event files under lib/slices/*/analytics/."""
    root = Path(tempfile.mkdtemp())
    (root / 'pubspec.yaml').write_text('name: habit_loop\n')
    for rel_path, content in analytics_files.items():
        f = root / rel_path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content)
    for rel_path, content in (lib_files or {}).items():
        f = root / rel_path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content)
    return root


class TestDetectOrphanedAnalyticsEvents(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, analytics_files: dict[str, str], lib_files: dict[str, str] | None = None) -> Path:
        root = _make_analytics_project(analytics_files, lib_files)
        self._roots.append(root)
        return root

    def test_referenced_event_not_reported(self):
        root = self._project(
            {'lib/slices/pact/analytics/pact_events.dart': 'final class PactCreatedEvent extends AnalyticsEvent {}'},
            {'lib/slices/pact/application/pact_service.dart': 'analytics.track(PactCreatedEvent());'},
        )
        self.assertEqual(detect_orphaned_analytics_events(root), [])

    def test_unreferenced_event_reported(self):
        root = self._project(
            {'lib/slices/pact/analytics/pact_events.dart': 'final class OrphanEvent extends AnalyticsEvent {}'},
        )
        self.assertIn('OrphanEvent', detect_orphaned_analytics_events(root))

    def test_reference_only_in_test_is_orphan(self):
        """A class referenced only in test/ is still an orphan — must appear in lib/."""
        root = self._project(
            {'lib/slices/pact/analytics/pact_events.dart': 'final class TestOnlyEvent extends AnalyticsEvent {}'},
            {'test/slices/pact/analytics/pact_events_test.dart': 'expect(TestOnlyEvent(), isA<AnalyticsEvent>());'},
        )
        self.assertIn('TestOnlyEvent', detect_orphaned_analytics_events(root))

    def test_reference_only_in_integration_test_is_orphan(self):
        """A class referenced only in integration_test/ is still an orphan."""
        root = self._project(
            {'lib/slices/pact/analytics/pact_events.dart': 'final class IntTestOnlyEvent extends AnalyticsEvent {}'},
            {'integration_test/scenario.dart': 'IntTestOnlyEvent();'},
        )
        # integration_test files must not count as lib references
        self.assertIn('IntTestOnlyEvent', detect_orphaned_analytics_events(root))

    def test_definition_file_itself_excluded_from_search(self):
        """The class name appearing in the file that defines it doesn't count as a reference."""
        root = self._project(
            {
                'lib/slices/pact/analytics/pact_events.dart': (
                    'final class SelfRefEvent extends AnalyticsEvent {\n'
                    '  SelfRefEvent();\n'
                    '}'
                ),
            },
        )
        self.assertIn('SelfRefEvent', detect_orphaned_analytics_events(root))

    def test_no_analytics_files_returns_empty(self):
        root = self._project({})
        self.assertEqual(detect_orphaned_analytics_events(root), [])

    def test_multiple_events_mixed(self):
        root = self._project(
            {
                'lib/slices/pact/analytics/pact_events.dart': (
                    'final class UsedEvent extends AnalyticsEvent {}\n'
                    'final class OrphanedEvent extends AnalyticsEvent {}'
                ),
            },
            {'lib/slices/pact/application/service.dart': 'analytics.track(UsedEvent());'},
        )
        orphans = detect_orphaned_analytics_events(root)
        self.assertNotIn('UsedEvent', orphans)
        self.assertIn('OrphanedEvent', orphans)

    def test_reference_in_another_slice_counts(self):
        """A class used in a different slice's lib/ file is not an orphan."""
        root = self._project(
            {'lib/slices/reminder/analytics/reminder_events.dart': 'final class ReminderFiredEvent extends AnalyticsEvent {}'},
            {'lib/slices/dashboard/application/dashboard_service.dart': 'analytics.track(ReminderFiredEvent());'},
        )
        self.assertEqual(detect_orphaned_analytics_events(root), [])

    def test_partial_class_name_not_counted(self):
        """'UsedEventExtra' must not count as a reference to 'UsedEvent'."""
        root = self._project(
            {'lib/slices/pact/analytics/pact_events.dart': 'final class UsedEvent extends AnalyticsEvent {}'},
            {'lib/slices/pact/application/service.dart': 'analytics.track(UsedEventExtra());'},
        )
        self.assertIn('UsedEvent', detect_orphaned_analytics_events(root))

    def test_file_outside_slice_analytics_dir_ignored(self):
        """Classes in lib/ but not in slices/*/analytics/ are not enumerated."""
        root = self._project(
            {'lib/infrastructure/analytics/base_event.dart': 'abstract class AnalyticsEvent {}'},
        )
        # base_event.dart is not under slices/*/analytics/ so no classes should be enumerated
        self.assertEqual(detect_orphaned_analytics_events(root), [])


if __name__ == '__main__':
    unittest.main()
