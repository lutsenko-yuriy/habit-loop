// Integration tests for the editable pact note on the pact detail screen (HAB-115).
//
// Run on host:   flutter test integration_test/pact_note_flow_test.dart
// Run on device: flutter test integration_test/pact_note_flow_test.dart -d <device>
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

/// Opens [habitName]'s pact detail from the pacts panel and waits for it to load.
Future<void> _openSettledPactDetail(AppHarness h, WidgetTester tester, String habitName) async {
  await h.dashboard.openPactsPanel();
  await h.dashboard.waitFor(find.text(habitName));
  await h.dashboard.openPactDetail(habitName);
  await h.pactDetail.waitLoaded();
  // Settle in-flight work from navigating in; a late rebuild could reset typed input (HAB-211).
  await tester.pumpAndSettle();
}

/// Polls the repo until [pactId]'s note equals [expectedNote] (HAB-258).
Future<void> _waitForNoteSaved(
  WidgetTester tester,
  AppHarness h,
  String pactId,
  String expectedNote,
) async {
  await waitUntil(
    tester,
    () async => ((await h.pactRepo.getPactById(pactId))?.stopReason ?? '') == expectedNote,
    timeout: const Duration(seconds: 45),
    description: 'pact $pactId stopReason never became "$expectedNote"',
  );
  // Fixed pumps: pumpAndSettle hangs here; the cache refresh is in-memory.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
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

      await _openSettledPactDetail(h, tester, 'Morning Run');

      // ── 1. Notes field is visible and pre-populated ───────────────────────
      await h.pactDetail.scrollToNoteField();
      expect(find.text('Got injured'), findsOneWidget);

      // ── 2. Save button is disabled (no changes yet) ────────────────────────
      expect(h.pactDetail.isSaveNoteEnabled, isFalse);

      // ── 3. Edit the note ───────────────────────────────────────────────────
      await h.pactDetail.enterNote('Injured knee — resting now');

      // ── 4. Save button becomes enabled ────────────────────────────────────
      expect(h.pactDetail.isSaveNoteEnabled, isTrue);

      // ── 5. Tap Save ────────────────────────────────────────────────────────
      await h.pactDetail.tapSaveNote();
      await _waitForNoteSaved(tester, h, _stoppedPact.id, 'Injured knee — resting now');

      // ── 6. Note is persisted ───────────────────────────────────────────────
      final saved = await h.pactRepo.getPactById(_stoppedPact.id);
      expect(saved?.stopReason, 'Injured knee — resting now');

      // ── 7. Save button is disabled again (no new unsaved changes) ─────────
      expect(h.pactDetail.isSaveNoteEnabled, isFalse);

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

      await _openSettledPactDetail(h, tester, 'Morning Run');
      await h.pactDetail.scrollToNoteField();

      await h.pactDetail.enterNote('');

      await h.pactDetail.tapSaveNote();
      await _waitForNoteSaved(tester, h, _stoppedPact.id, '');

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
      await _openSettledPactDetail(h, tester, 'Morning Run');
      final strings = l10n(tester);

      // ── 3. Edit the note and save ────────────────────────────────────────────
      await h.pactDetail.scrollToNoteField();
      await h.pactDetail.enterNote('Injured knee — resting now');

      await h.pactDetail.tapSaveNote();
      await _waitForNoteSaved(tester, h, _stoppedPact.id, 'Injured knee — resting now');

      // ── 4. Open Timeline from the same still-open Pact Detail screen ────────
      // Longer-than-default timeouts below (HAB-258): a CI run observed this
      // navigation alone take ~52s under heavy load — waitFor's usual 30s
      // default isn't always enough for this specific screen transition.
      await h.pactDetail.openTimeline();
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle), timeout: const Duration(seconds: 60));

      // ── 5. The updated note is reflected; the original text is gone ─────────
      // Pact Detail remains in the nav stack below Timeline, so its own
      // pact-note-field still shows the new text too — two matches expected.
      await waitFor(tester, find.text('Injured knee — resting now'), timeout: const Duration(seconds: 60));
      expect(find.text('Injured knee — resting now'), findsAtLeastNWidgets(1));
      // Timeline's note comes from PactDetailCache, not the repository
      // _waitForNoteSaved above already confirmed — waitFor(the new text)
      // is satisfiable by Pact Detail's own note field alone (findsAtLeastNWidgets(1)
      // accepts one match), so it doesn't guarantee Timeline itself has
      // re-rendered yet. Wait for the old text to actually disappear instead
      // of asserting on it with no wait (HAB-258 audit finding on PR #440).
      await waitForGone(tester, find.text('Got injured'), timeout: const Duration(seconds: 60));
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

      await _openSettledPactDetail(h, tester, 'Evening Walk');
      await h.pactDetail.scrollToNoteField();

      // ── 1. Field starts empty ─────────────────────────────────────────────
      expect(h.pactDetail.noteText, isEmpty);

      // ── 2. Write and save ─────────────────────────────────────────────────
      await h.pactDetail.enterNote('Felt great throughout!');

      await h.pactDetail.tapSaveNote();
      await _waitForNoteSaved(tester, h, _completedPact.id, 'Felt great throughout!');

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

      // Navigate via showup tile — active pacts have a live showup on the dashboard.
      await waitFor(tester, find.text('Meditate'));
      await h.dashboard.openShowup('Meditate');
      await h.showupDetail.waitForMarkDone();

      await h.showupDetail.viewPactDetails();
      await h.pactDetail.waitLoaded();
      await h.pactDetail.scrollToStopPact();

      expect(find.byKey(const Key('pact-note-field')), findsNothing);
      expect(find.byKey(const Key('pact-note-save-button')), findsNothing);
    });
  });
}
