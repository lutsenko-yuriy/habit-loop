// Integration tests for the editable pact note on the pact detail screen (HAB-115).
//
// Run on host:   flutter test integration_test/pact_note_flow_test.dart
// Run on device: flutter test integration_test/pact_note_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _stoppedPact = Pact(
  id: 'pact-note-test-stopped',
  habitName: 'Morning Run',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
  stopReason: 'Got injured',
  createdAt: DateTime(2099, 1, 1),
  stoppedAt: DateTime(2099, 3, 1),
);

final _completedPact = Pact(
  id: 'pact-note-test-completed',
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.completed,
  createdAt: DateTime(2099, 1, 1),
);

const _activePactId = 'pact-note-test-active';
const _activeShowupId = '${_activePactId}_20990615T080000_0';

final _activePact = Pact(
  id: _activePactId,
  habitName: 'Meditate',
  startDate: _testToday,
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: _testToday,
);

final _activeShowup = Showup(
  id: _activeShowupId,
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns whether the pact-note-save-button is enabled on any platform.
bool _saveButtonEnabled(WidgetTester tester) {
  final w = tester.widget(find.byKey(const Key('pact-note-save-button')));
  if (w is ButtonStyleButton) return w.onPressed != null;
  return (w as CupertinoButton).onPressed != null;
}

/// Returns the current text of the pact-note-field on any platform.
String _noteFieldText(WidgetTester tester) {
  final w = tester.widget(find.byKey(const Key('pact-note-field')));
  if (w is TextField) return w.controller?.text ?? '';
  return (w as CupertinoTextField).controller?.text ?? '';
}

/// Expands the pacts panel and taps [habitName] to open PactDetailScreen.
Future<void> _openInactivePactDetail(WidgetTester tester, String habitName) async {
  await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
  await tester.pump(const Duration(milliseconds: 400));
  await waitFor(tester, find.text(habitName));
  await tester.tap(find.text(habitName).last);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
  // sectionStats is near the top of _PactDetailContent and only rendered after
  // the VM finishes loading — reliable on any screen size. The note field is
  // below the fold; each test uses scrollUntilVisible to bring it into view.
  await waitFor(tester, find.text(l10n(tester).sectionStats.toUpperCase()));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact note — stopped pact with existing note', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('existing stop reason is pre-populated; editing and saving persists the new note', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_stoppedPact);
        },
      );

      await _openInactivePactDetail(tester, 'Morning Run');

      // ── 1. Notes field is visible and pre-populated ───────────────────────
      // The note section is below the fold on small screens — scroll to reveal.
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        // The dashboard body also has a Scrollable; supply the ancestor
        // Scrollable of the note field itself to avoid an ambiguous match.
        scrollable: find.ancestor(
          of: find.byKey(const Key('pact-note-field')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Got injured'), findsOneWidget);

      // ── 2. Save button is disabled (no changes yet) ────────────────────────
      expect(_saveButtonEnabled(tester), isFalse);

      // ── 3. Edit the note ───────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-note-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pact-note-field')), 'Injured knee — resting now');
      await tester.pump();

      // ── 4. Save button becomes enabled ────────────────────────────────────
      expect(_saveButtonEnabled(tester), isTrue);

      // ── 5. Tap Save ────────────────────────────────────────────────────────
      // The stopped-date row + View Timeline button push the save button near the
      // viewport edge; ensureVisible scrolls it fully into view before tapping.
      await tester.ensureVisible(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ── 6. Note is persisted ───────────────────────────────────────────────
      final saved = await h.pactRepo.getPactById(_stoppedPact.id);
      expect(saved?.stopReason, 'Injured knee — resting now');

      // ── 7. Save button is disabled again (no new unsaved changes) ─────────
      await waitFor(tester, find.byKey(const Key('pact-note-save-button')));
      expect(_saveButtonEnabled(tester), isFalse);

      // ── 8. pact_note_saved analytics event was fired ───────────────────────
      expect(h.analytics.loggedEvents.any((e) => e.name == 'pact_note_saved'), isTrue);
    });

    testWidgets('clearing the note saves an empty value', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_stoppedPact);
        },
      );

      await _openInactivePactDetail(tester, 'Morning Run');
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        // The dashboard body also has a Scrollable; supply the ancestor
        // Scrollable of the note field itself to avoid an ambiguous match.
        scrollable: find.ancestor(
          of: find.byKey(const Key('pact-note-field')),
          matching: find.byType(Scrollable),
        ),
      );

      await tester.tap(find.byKey(const Key('pact-note-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pact-note-field')), '');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saved = await h.pactRepo.getPactById(_stoppedPact.id);
      expect(saved?.stopReason ?? '', isEmpty);
    });
  });

  group('Pact note — completed pact with no prior note', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('empty note field is shown; writing and saving persists the note', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_completedPact);
        },
      );

      await _openInactivePactDetail(tester, 'Evening Walk');
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        // The dashboard body also has a Scrollable; supply the ancestor
        // Scrollable of the note field itself to avoid an ambiguous match.
        scrollable: find.ancestor(
          of: find.byKey(const Key('pact-note-field')),
          matching: find.byType(Scrollable),
        ),
      );

      // ── 1. Field starts empty ─────────────────────────────────────────────
      expect(_noteFieldText(tester), isEmpty);

      // ── 2. Write and save ─────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-note-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pact-note-field')), 'Felt great throughout!');
      await tester.pump();

      await tester.tap(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saved = await h.pactRepo.getPactById(_completedPact.id);
      expect(saved?.stopReason, 'Felt great throughout!');
    });
  });

  group('Pact note — active pact', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('notes section is not visible on an active pact detail', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_activePact);
          await h.showupRepo.saveShowups([_activeShowup]);
        },
      );

      final strings = l10n(tester);

      // Navigate via showup tile — active pacts have a live showup on the dashboard.
      await waitFor(tester, find.text('Meditate'));
      await tester.tap(find.text('Meditate'));
      await waitFor(tester, find.text(strings.markDone));

      await tester.tap(find.text(strings.showupViewPactDetails));
      // sectionStats is near the top of _PactDetailContent and only rendered after
      // the VM finishes loading — reliable on any screen size. Stop Pact lives at
      // the bottom of the ListView; use sectionStats to scope the Scrollable so
      // scrollUntilVisible works even when stopPact is not yet built.
      await waitFor(tester, find.text(strings.sectionStats.toUpperCase()));
      await tester.scrollUntilVisible(
        find.text(strings.stopPact),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.byKey(const Key('pact-note-field')), findsNothing);
      expect(find.byKey(const Key('pact-note-save-button')), findsNothing);
    });
  });
}
