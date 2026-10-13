// Integration tests for archive / unarchive pacts (HAB-114).
//
// Run on host:   flutter test integration_test/archive_pact_flow_test.dart
// Run on device: flutter test integration_test/archive_pact_flow_test.dart -d <device>
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

final _completedPact = buildPact(
  id: 'archive-test-completed',
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.completed,
);

final _stoppedPact = buildPact(
  id: 'archive-test-stopped',
  habitName: 'Morning Run',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 3, 31),
  showupDuration: const Duration(minutes: 30),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
);

final _archivedCompletedPact = buildPact(
  id: 'archive-test-arch-completed',
  habitName: 'Cycling',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 2, 28),
  showupDuration: const Duration(minutes: 45),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
  status: PactStatus.completed,
  archived: true,
);

final _archivedStoppedPact = buildPact(
  id: 'archive-test-arch-stopped',
  habitName: 'Yoga',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 2, 28),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 6)),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 2, 1),
  archived: true,
);

const _activePactId = 'archive-test-active';
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Archive pact — detail screen', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('archive_completed_pact_from_detail: archiving marks pact archived and fires analytics',
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

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Evening Walk');

      // Wait for the detail content to load (habit name appears in _PactDetailContent).
      await waitFor(tester, find.text('Evening Walk'));
      // The "View Timeline" button (enabled by default) adds height, pushing the
      // archive section below the initial viewport. Scroll down to build it.
      await h.pactDetail.scrollDownFrom('Evening Walk');

      // ── 1. Archive button is visible ──────────────────────────────────────
      await h.pactDetail.waitForArchiveButton();
      expect(find.text(strings.archivePact), findsOneWidget);

      // ── 2. Tap Archive ────────────────────────────────────────────────────
      await h.pactDetail.tapArchiveButton();

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

      await openPactsPanel(tester);

      // ── 1. Enable Show archived pacts to make the pact visible ────────────
      await h.dashboard.waitForArchivedRow();
      await h.dashboard.tapArchivedRow();

      // Scroll the archived tile into view in case it extends below the panel.
      await waitFor(tester, find.text('Yoga'));
      await tester.ensureVisible(find.text('Yoga').last);
      await tester.pump();

      await openPactDetail(tester, 'Yoga');

      // ── 2. Confirm we reached the pact detail screen ──────────────────────
      await waitFor(tester, find.text(strings.pactDetailTitle));
      // Wait for load() to complete — habit name appears at the top of the content.
      await waitFor(tester, find.text('Yoga'));

      // ── 3. Unarchive button is visible ────────────────────────────────────
      // The stopped-pact extras push the archive button below the viewport; drag to build it.
      await h.pactDetail.scrollDownFrom('Yoga');

      await h.pactDetail.waitForArchiveButton();
      expect(find.text(strings.unarchivePact), findsOneWidget);

      // ── 4. Tap Unarchive ─────────────────────────────────────────────────
      await h.pactDetail.tapArchiveButton();

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
      // sectionStats is near the top of _PactDetailContent and only rendered
      // after the VM finishes loading — reliable on any screen size.
      await waitFor(tester, find.text(strings.sectionStats.toUpperCase()));

      expect(find.byKey(const Key('archive-pact-button')), findsNothing);
    });
  });

  group('Archive pact — pact list', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('archived_row_hidden_then_revealed: row absent at N_A=0 and appears after first archive',
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

      await openPactsPanel(tester);

      // ── 1. No "Archived pacts" row when N_A = 0 ───────────────────────────
      expect(find.byKey(const Key('show-archived-pacts-row')), findsNothing);

      // ── 2. Archive via detail screen ──────────────────────────────────────
      await openPactDetail(tester, 'Evening Walk');
      await waitFor(tester, find.text('Evening Walk'));
      await h.pactDetail.scrollDownFrom('Evening Walk');
      await h.pactDetail.waitForArchiveButton();
      await h.pactDetail.tapArchiveButton(settle: const Duration(milliseconds: 300));

      // ── 3. Navigate back to pacts panel ───────────────────────────────────
      // pumpAndSettle drains AnimatedSize animation before pageBack() tries to
      // hit-test the back button.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));

      // ── 4. "Archived pacts" row now visible (N_A = 1) ─────────────────────
      await h.dashboard.waitForArchivedRow();
    });

    testWidgets('archived_row_toggles_visibility: tapping the row reveals then hides the archived pact',
        (tester) async {
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

      await openPactsPanel(tester);

      // ── 1. Row visible; archived pact not shown ───────────────────────────
      await h.dashboard.waitForArchivedRow();
      expect(find.text('Cycling'), findsNothing);

      // ── 2. Tap row → archived pact appears ─────────────────────────────────
      await h.dashboard.scrollArchivedRowIntoView();
      await h.dashboard.tapArchivedRow(settle: const Duration(milliseconds: 300));
      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text(strings.archivedPacts(1)), findsOneWidget);

      // ── 3. Tap row again → archived pact disappears ────────────────────────
      await h.dashboard.tapArchivedRow(settle: const Duration(milliseconds: 300));
      expect(find.text('Cycling'), findsNothing);
    });

    testWidgets('sort_order_with_archived_pacts: active→unarch-done→unarch-stopped→arch-done→arch-stopped',
        (tester) async {
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

      await openPactsPanel(tester);
      // Snap the panel to maxSize so all unarchived pacts and the toggle row are visible.
      await h.dashboard.flingPanelToMax();

      // ── Enable Show archived pacts ─────────────────────────────────────────
      await waitFor(tester, find.text('Evening Walk'));
      await h.dashboard.waitForArchivedRow();
      // Items may overflow the panel height.
      await h.dashboard.scrollArchivedRowIntoView();
      await tester.pump();
      await h.dashboard.tapArchivedRow();

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
