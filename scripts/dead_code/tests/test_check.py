from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from dead_code.check import (
    detect_orphaned_analytics_events,
    detect_orphaned_handlers,
    detect_orphaned_l10n_keys,
    detect_orphaned_test_files,
)


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


class TestDetectOrphanedTestFiles(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, test_files: dict[str, str], lib_files: dict[str, str] | None = None) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        (root / 'pubspec.yaml').write_text('name: habit_loop\n')
        for rel_path, content in test_files.items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        for rel_path, content in (lib_files or {}).items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        return root

    def test_existing_import_not_reported(self):
        root = self._project(
            {'test/pact_test.dart': "import 'package:habit_loop/slices/pact/domain/pact.dart';"},
            {'lib/slices/pact/domain/pact.dart': 'class Pact {}'},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertEqual(high, [])
        self.assertEqual(info, [])

    def test_all_imports_missing_is_high_confidence(self):
        root = self._project(
            {'test/removed_test.dart': "import 'package:habit_loop/slices/removed/feature.dart';"},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertIn('test/removed_test.dart', high)
        self.assertEqual(info, [])

    def test_no_package_imports_is_informational(self):
        root = self._project(
            {'test/util_test.dart': "import 'dart:math';\nimport 'package:test/test.dart';"},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertEqual(high, [])
        self.assertIn('test/util_test.dart', info)

    def test_mixed_imports_one_existing_not_high_confidence(self):
        """At least one existing import means the file is not high-confidence."""
        root = self._project(
            {
                'test/partial_test.dart': (
                    "import 'package:habit_loop/slices/pact/domain/pact.dart';\n"
                    "import 'package:habit_loop/slices/removed/gone.dart';\n"
                ),
            },
            {'lib/slices/pact/domain/pact.dart': 'class Pact {}'},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertNotIn('test/partial_test.dart', high)
        self.assertNotIn('test/partial_test.dart', info)

    def test_integration_test_dir_included(self):
        root = self._project(
            {'integration_test/removed_scenario.dart': "import 'package:habit_loop/removed.dart';"},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertIn('integration_test/removed_scenario.dart', high)

    def test_no_test_dirs_returns_empty(self):
        root = self._project({})
        high, info = detect_orphaned_test_files(root)
        self.assertEqual(high, [])
        self.assertEqual(info, [])

    def test_multiple_missing_imports_all_flagged(self):
        root = self._project(
            {
                'test/orphan_a.dart': "import 'package:habit_loop/gone_a.dart';",
                'test/orphan_b.dart': "import 'package:habit_loop/gone_b.dart';",
                'test/live.dart': "import 'package:habit_loop/live.dart';",
            },
            {'lib/live.dart': 'class Live {}'},
        )
        high, info = detect_orphaned_test_files(root)
        self.assertIn('test/orphan_a.dart', high)
        self.assertIn('test/orphan_b.dart', high)
        self.assertNotIn('test/live.dart', high)


_NS_PATH = 'lib/infrastructure/notifications/data/flutter_local_notification_service.dart'


class TestDetectOrphanedHandlers(unittest.TestCase):

    def setUp(self):
        self._roots: list[Path] = []

    def tearDown(self):
        for root in self._roots:
            shutil.rmtree(root, ignore_errors=True)

    def _project(self, lib_files: dict[str, str]) -> Path:
        root = Path(tempfile.mkdtemp())
        self._roots.append(root)
        (root / 'pubspec.yaml').write_text('name: habit_loop\n')
        for rel_path, content in lib_files.items():
            f = root / rel_path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(content)
        return root

    # --- Handler file sub-check ---

    def test_imported_handler_not_reported(self):
        root = self._project({
            'lib/slices/dashboard/ui/generic/sync_status_handler.dart': 'class SyncStatusHandler {}',
            'lib/slices/dashboard/ui/ios/dashboard_page.dart': (
                "import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';"
            ),
        })
        files, _ = detect_orphaned_handlers(root)
        self.assertEqual(files, [])

    def test_unimported_handler_reported(self):
        root = self._project({
            'lib/slices/dashboard/ui/generic/orphan_handler.dart': 'class OrphanHandler {}',
        })
        files, _ = detect_orphaned_handlers(root)
        self.assertIn('lib/slices/dashboard/ui/generic/orphan_handler.dart', files)

    def test_import_in_test_file_counts(self):
        root = self._project({
            'lib/slices/dashboard/ui/generic/some_handler.dart': 'class SomeHandler {}',
        })
        test_dir = root / 'test'
        test_dir.mkdir()
        (test_dir / 'some_handler_test.dart').write_text(
            "import 'package:habit_loop/slices/dashboard/ui/generic/some_handler.dart';"
        )
        files, _ = detect_orphaned_handlers(root)
        self.assertEqual(files, [])

    def test_no_handler_files_returns_empty(self):
        root = self._project({'lib/main.dart': 'void main() {}'})
        files, entry_points = detect_orphaned_handlers(root)
        self.assertEqual(files, [])
        self.assertEqual(entry_points, [])

    # --- vm:entry-point sub-check ---

    def test_entry_point_wired_in_service_not_reported(self):
        root = self._project({
            'lib/background_handler.dart': (
                "@pragma('vm:entry-point')\nvoid onBackground() {}"
            ),
            _NS_PATH: 'onBackground',
        })
        _, entry_points = detect_orphaned_handlers(root)
        self.assertEqual(entry_points, [])

    def test_entry_point_not_wired_reported(self):
        root = self._project({
            'lib/background_handler.dart': (
                "@pragma('vm:entry-point')\nvoid onBackground() {}"
            ),
            _NS_PATH: '// notification service — no reference here',
        })
        _, entry_points = detect_orphaned_handlers(root)
        self.assertIn('onBackground', entry_points)

    def test_entry_point_no_notification_service_reported(self):
        root = self._project({
            'lib/background_handler.dart': (
                "@pragma('vm:entry-point')\nvoid onBackground() {}"
            ),
        })
        _, entry_points = detect_orphaned_handlers(root)
        self.assertIn('onBackground', entry_points)

    def test_future_return_type_entry_point(self):
        root = self._project({
            'lib/background_handler.dart': (
                "@pragma('vm:entry-point')\nFuture<void> onBackground() async {}"
            ),
            _NS_PATH: '// no reference',
        })
        _, entry_points = detect_orphaned_handlers(root)
        self.assertIn('onBackground', entry_points)


if __name__ == '__main__':
    unittest.main()
