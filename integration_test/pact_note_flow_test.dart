// Integration tests for the editable pact note on the pact detail screen (HAB-115).
//
// Run on host:   flutter test integration_test/pact_note_flow_test.dart
// Run on device: flutter test integration_test/pact_note_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _stoppedPact = buildPact(
  id: 'pact-note-test-stopped',
  habitName: 'Morning Run',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 30),
  status: PactStatus.stopped,
  stopReason: 'Got injured',
  stoppedAt: DateTime(2099, 3, 1),
);

final _completedPact = buildPact(
  id: 'pact-note-test-completed',
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.completed,
);

const _activePactId = 'pact-note-test-active';
const _activeShowupId = '${_activePactId}_20990615T080000_0';

final _activePact = buildPact(
  id: _activePactId,
  habitName: 'Meditate',
  startDate: _testToday,
);

final _activeShowup = buildShowup(
  id: _activeShowupId,
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
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

    testWidgets(
        'existing_stop_reason_prepopulated_and_editable: existing stop reason is pre-populated; editing and saving persists the new note',
        (tester) async {
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
      final strings = l10n(tester);

      // ── 1. Notes field is visible and pre-populated ───────────────────────
      // The note section is below the fold on small screens — scroll to reveal.
      // Use sectionStats (already in the tree after _openInactivePactDetail) as
      // the scrollable anchor instead of pact-note-field, which is not yet
      // built by the lazy ListView when scrollUntilVisible first evaluates the
      // finder (causing Iterable.single: No element on narrow CI screens).
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
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

    testWidgets('clearing_note_saves_empty_value: clearing the note field and saving persists an empty value',
        (tester) async {
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
      final strings = l10n(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
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

    testWidgets(
        'note_write_through_visible_in_timeline_same_session: editing the pact note is reflected in Timeline '
        'without an app restart (HAB-174)', (tester) async {
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

      // ── 1/2. Open Pact Detail — first open this session, warms the cache
      //         with the original note ("Got injured") ────────────────────────
      await _openInactivePactDetail(tester, 'Morning Run');
      final strings = l10n(tester);

      // ── 3. Edit the note and save ────────────────────────────────────────────
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('pact-note-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pact-note-field')), 'Injured knee — resting now');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-note-save-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ── 4. Open Timeline from the same still-open Pact Detail screen ────────
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── 5. The updated note is reflected; the original text is gone ─────────
      // Pact Detail remains in the nav stack below Timeline, so its own
      // pact-note-field still shows the new text too — two matches expected.
      await waitFor(tester, find.text('Injured knee — resting now'));
      expect(find.text('Injured knee — resting now'), findsAtLeastNWidgets(1));
      expect(find.text('Got injured'), findsNothing);
    });
  });

  group('Pact note — completed pact with no prior note', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'empty_note_field_writable_and_persists: empty note field is shown; writing and saving persists the note',
        (tester) async {
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
      final strings = l10n(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('pact-note-field')),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
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

      // Scroll the save button into view before tapping — the software keyboard
      // opened by the text field pushes the button off-screen on small CI AVDs.
      await tester.ensureVisible(find.byKey(const Key('pact-note-save-button')));
      await tester.pumpAndSettle();
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

    testWidgets('notes_section_hidden_on_active_pact: notes section is not visible on an active pact detail',
        (tester) async {
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
