// Integration tests for archive / unarchive pacts (HAB-114).
//
// Run on host:   flutter test integration_test/archive_pact_flow_test.dart
// Run on device: flutter test integration_test/archive_pact_flow_test.dart -d <device>
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

final _completedPact = Pact(
  id: 'archive-test-completed',
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.completed,
  createdAt: DateTime(2099, 1, 1),
);

final _stoppedPact = Pact(
  id: 'archive-test-stopped',
  habitName: 'Morning Run',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.stopped,
  createdAt: DateTime(2099, 1, 1),
  stoppedAt: DateTime(2099, 3, 1),
);

// RED until WU1 adds Pact.archived — these constructors will not compile.
final _archivedCompletedPact = Pact(
  id: 'archive-test-arch-completed',
  habitName: 'Cycling',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 2, 28),
  showupDuration: const Duration(minutes: 45),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
  status: PactStatus.completed,
  createdAt: DateTime(2099, 1, 1),
  archived: true,
);

final _archivedStoppedPact = Pact(
  id: 'archive-test-arch-stopped',
  habitName: 'Yoga',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 2, 28),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 6)),
  status: PactStatus.stopped,
  createdAt: DateTime(2099, 1, 1),
  stoppedAt: DateTime(2099, 2, 1),
  archived: true,
);

const _activePactId = 'archive-test-active';
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

Future<void> _openPactsPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openPactDetail(WidgetTester tester, String habitName) async {
  await waitFor(tester, find.text(habitName));
  await tester.tap(find.text(habitName).last);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Archive pact — detail screen', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('archive_completed_pact_from_detail: archiving marks pact archived and fires analytics', (tester) async {
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

      final strings = l10n(tester);

      await _openPactsPanel(tester);
      await _openPactDetail(tester, 'Evening Walk');

      // ── 1. Archive button is visible ──────────────────────────────────────
      await waitFor(tester, find.byKey(const Key('archive-pact-button')));
      expect(find.text(strings.archivePact), findsOneWidget);

      // ── 2. Tap Archive ────────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('archive-pact-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ── 3. Pact is archived in repository ─────────────────────────────────
      final saved = await h.pactRepo.getPactById(_completedPact.id);
      expect(saved?.archived, isTrue);

      // ── 4. Button label switches to Unarchive ─────────────────────────────
      expect(find.text(strings.unarchivePact), findsOneWidget);

      // ── 5. pact_archived event with source: detail_screen ─────────────────
      expect(
        h.analytics.loggedEvents.any(
          (e) => e.name == 'pact_archived' && e.toParameters()['source'] == 'detail_screen',
        ),
        isTrue,
      );
    });

    testWidgets('unarchive_pact_from_detail: unarchiving marks pact unarchived and fires analytics', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_archivedStoppedPact);
        },
      );

      final strings = l10n(tester);

      await _openPactsPanel(tester);

      // ── 1. Enable Show archived pacts to make the pact visible ────────────
      await waitFor(tester, find.byKey(const Key('show-archived-pacts-row')));
      await tester.tap(find.byKey(const Key('show-archived-pacts-row')));
      await tester.pump(const Duration(milliseconds: 200));

      await _openPactDetail(tester, 'Yoga');

      // ── 2. Unarchive button is visible ────────────────────────────────────
      await waitFor(tester, find.byKey(const Key('archive-pact-button')));
      expect(find.text(strings.unarchivePact), findsOneWidget);

      // ── 3. Tap Unarchive ──────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('archive-pact-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ── 4. Pact is unarchived in repository ───────────────────────────────
      final saved = await h.pactRepo.getPactById(_archivedStoppedPact.id);
      expect(saved?.archived, isFalse);

      // ── 5. Button label switches back to Archive ──────────────────────────
      expect(find.text(strings.archivePact), findsOneWidget);

      // ── 6. pact_unarchived event fired ────────────────────────────────────
      expect(h.analytics.loggedEvents.any((e) => e.name == 'pact_unarchived'), isTrue);
    });

    testWidgets('active_pact_has_no_archive_button: archive button is absent on active pact detail', (tester) async {
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

      await waitFor(tester, find.text('Meditate'));
      await tester.tap(find.text('Meditate'));
      await waitFor(tester, find.text(strings.markDone));

      await tester.tap(find.text(strings.showupViewPactDetails));
      await waitFor(tester, find.text(strings.stopPact));

      expect(find.byKey(const Key('archive-pact-button')), findsNothing);
    });
  });

  group('Archive pact — pact list', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('archived_chip_row_hidden_then_revealed: chip row absent at N_A=0 and appears after first archive', (tester) async {
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

      await _openPactsPanel(tester);

      // ── 1. No Archived chip when N_A = 0 ──────────────────────────────────
      expect(find.byKey(const Key('archive-filter-chip')), findsNothing);

      // ── 2. Archive via detail screen ──────────────────────────────────────
      await _openPactDetail(tester, 'Evening Walk');
      await waitFor(tester, find.byKey(const Key('archive-pact-button')));
      await tester.tap(find.byKey(const Key('archive-pact-button')));
      await tester.pump(const Duration(milliseconds: 100));

      // ── 3. Navigate back to pacts panel ───────────────────────────────────
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      // ── 4. Archived chip row now visible (N_A = 1) ────────────────────────
      await waitFor(tester, find.byKey(const Key('archive-filter-chip')));
    });

    testWidgets('archived_chip_syncs_with_show_row: chip and show-archived row toggle each other', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_archivedCompletedPact);
        },
      );

      final strings = l10n(tester);

      await _openPactsPanel(tester);

      // ── 1. Archived chip visible; archived pact not shown ─────────────────
      await waitFor(tester, find.byKey(const Key('archive-filter-chip')));
      expect(find.text('Cycling'), findsNothing);

      // ── 2. Tap chip → archived pact appears ───────────────────────────────
      await tester.tap(find.byKey(const Key('archive-filter-chip')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cycling'), findsOneWidget);

      // ── 3. Show-archived row is also toggled on ────────────────────────────
      expect(find.text(strings.showArchivedPacts(1)), findsOneWidget);

      // ── 4. Tap show row → archived pact disappears; chip deselected ───────
      await tester.tap(find.byKey(const Key('show-archived-pacts-row')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cycling'), findsNothing);
    });

    testWidgets('swipe_to_archive_pact: swipe-left reveals Archive; tapping archives pact with correct analytics', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_stoppedPact);
        },
      );

      final strings = l10n(tester);

      await _openPactsPanel(tester);
      await waitFor(tester, find.text('Morning Run'));

      // ── 1. Swipe left on the pact tile ────────────────────────────────────
      await tester.drag(find.text('Morning Run'), const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 300));

      // ── 2. Archive action button is revealed ──────────────────────────────
      await waitFor(tester, find.byKey(const Key('swipe-archive-button')));
      expect(find.text(strings.archivePact), findsOneWidget);

      // ── 3. Tap Archive ────────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('swipe-archive-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ── 4. Pact is archived in repository ─────────────────────────────────
      final saved = await h.pactRepo.getPactById(_stoppedPact.id);
      expect(saved?.archived, isTrue);

      // ── 5. pact_archived event with source: pact_list_swipe ───────────────
      expect(
        h.analytics.loggedEvents.any(
          (e) => e.name == 'pact_archived' && e.toParameters()['source'] == 'pact_list_swipe',
        ),
        isTrue,
      );
    });

    testWidgets('sort_order_with_archived_pacts: active→unarch-done→unarch-stopped→arch-done→arch-stopped', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_activePact);
          await h.pactRepo.savePact(_completedPact);
          await h.pactRepo.savePact(_stoppedPact);
          await h.pactRepo.savePact(_archivedCompletedPact);
          await h.pactRepo.savePact(_archivedStoppedPact);
          await h.showupRepo.saveShowups([_activeShowup]);
        },
      );

      await _openPactsPanel(tester);

      // ── Enable Show archived pacts ─────────────────────────────────────────
      await waitFor(tester, find.byKey(const Key('show-archived-pacts-row')));
      await tester.tap(find.byKey(const Key('show-archived-pacts-row')));
      await tester.pump(const Duration(milliseconds: 300));

      await waitFor(tester, find.text('Yoga'));

      // ── Verify vertical order by top-left y-coordinate ────────────────────
      double dy(String name) => tester.getTopLeft(find.text(name).last).dy;

      expect(dy('Meditate'), lessThan(dy('Evening Walk')));
      expect(dy('Evening Walk'), lessThan(dy('Morning Run')));
      expect(dy('Morning Run'), lessThan(dy('Cycling')));
      expect(dy('Cycling'), lessThan(dy('Yoga')));
    });
  });
}
