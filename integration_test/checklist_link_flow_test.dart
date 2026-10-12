// Scenarios for GH-464: linking a Checklister checklist to a pact.
//
// Run with: flutter test integration_test/checklist_link_flow_test.dart -d <device>
// Run on host: flutter test integration_test/checklist_link_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

const _flagOn = {'checklister_integration_enabled': true};

const _pactId = 'checklist-link-pact';
const _showupId = '${_pactId}_20990615T080000_0';
const _selectKey = Key('pact-checklist-select-button');
const _changeKey = Key('pact-checklist-change-button');
const _removeKey = Key('pact-checklist-remove-button');

final _activePact = buildPact(id: _pactId, habitName: 'Meditate', startDate: _testToday);

PactChecklistLink _link(String id, String name) =>
    PactChecklistLink(pactId: _pactId, checklistId: id, checklistName: name, linkedAt: DateTime(2099, 6, 1));

/// The callback Checklister would open after the picker, with its own params appended.
Uri _selectionCallback(String query) => Uri.parse('${ChecklisterLinks.selectedCallback(_pactId)}&$query');

List<Override> get _clock => [
      todayProvider.overrideWithValue(_testNow),
      pactDetailNowProvider.overrideWithValue(_testNow),
    ];

/// Scrolls pact detail until [finder] is on screen (the section sits below the fold on short viewports).
Future<void> _scrollTo(WidgetTester tester, String pactId, Finder finder) async {
  await waitFor(tester, find.byKey(Key('pact-detail-scroll-view-$pactId')));
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(
      of: find.byKey(Key('pact-detail-scroll-view-$pactId')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester, String habitName) async {
  await openPactsPanel(tester);
  await openPactDetail(tester, habitName);
  await waitFor(tester, find.text(l10n(tester).sectionStats.toUpperCase()));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Checklist link flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('no_checklist_section_when_checklister_not_installed: pact detail has no Checklist section',
        (tester) async {
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async {
          h.checklister.installed = false;
          await h.pactRepo.savePact(_activePact);
        },
      );

      await _openDetail(tester, 'Meditate');
      await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(_selectKey), findsNothing);
      expect(find.text(l10n(tester).pactChecklistSectionTitle.toUpperCase()), findsNothing);
    });

    testWidgets('select_checklist_links_checklist_to_pact: a selected callback shows the linked checklist on the pact',
        (tester) async {
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async => h.pactRepo.savePact(_activePact),
      );

      // 2. Only "Select checklist" is offered.
      await _openDetail(tester, 'Meditate');
      await _scrollTo(tester, _pactId, find.byKey(_selectKey));
      expect(find.byKey(_changeKey), findsNothing);
      expect(find.byKey(_removeKey), findsNothing);

      // 3. Tapping it opens Checklister with our selected-callback URL.
      await tester.tap(find.byKey(_selectKey));
      await tester.pumpAndSettle();
      final launched = h.checklister.launchedUrls.single;
      expect(launched.scheme, 'checklister');
      expect(launched.host, 'select');
      expect(launched.queryParameters['callbackUrl'], ChecklisterLinks.selectedCallback(_pactId).toString());

      // 4-5. Checklister calls back with a selection; the section shows it.
      h.incomingLinks.emit(_selectionCallback('status=selected&checklistId=c1&checklistName=Morning'));
      await waitFor(tester, find.text('Morning'));
      await tester.pumpAndSettle(); // let the empty -> linked crossfade finish
      expect(find.byKey(_changeKey), findsOneWidget);
      expect(find.byKey(_removeKey), findsOneWidget);
      expect(find.byKey(_selectKey), findsNothing);

      // 6. Persisted.
      final stored = await h.checklistLinkRepo.getForPact(_pactId);
      expect([stored?.checklistId, stored?.checklistName], ['c1', 'Morning']);

      // 7. Analytics.
      final started = h.analytics.loggedEvents.whereType<PactChecklistSelectionStartedEvent>().single;
      expect([started.pactId, started.mode], [_pactId, 'select']);
      final linked = h.analytics.loggedEvents.whereType<PactChecklistLinkedEvent>().single;
      expect([linked.pactId, linked.mode], [_pactId, 'select']);
    });

    testWidgets(
        'selection_cancelled_or_error_leaves_pact_unlinked: cancelled changes nothing, error asks to select something',
        (tester) async {
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async => h.pactRepo.savePact(_activePact),
      );
      await _openDetail(tester, 'Meditate');
      await _scrollTo(tester, _pactId, find.byKey(_selectKey));
      final strings = l10n(tester);

      // 1-2. Cancelled: still "Select checklist", no message, nothing stored.
      await tester.tap(find.byKey(_selectKey));
      await tester.pumpAndSettle();
      h.incomingLinks.emit(_selectionCallback('status=cancelled'));
      await tester.pumpAndSettle();
      expect(find.byKey(_selectKey), findsOneWidget);
      expect(find.text(strings.pactChecklistNoChecklistsError), findsNothing);
      expect(await h.checklistLinkRepo.getForPact(_pactId), isNull);

      // 3-4. Error (no checklists in Checklister): message shown, still unlinked.
      await tester.tap(find.byKey(_selectKey));
      await tester.pumpAndSettle();
      h.incomingLinks.emit(_selectionCallback('status=error'));
      await waitFor(tester, find.text(strings.pactChecklistNoChecklistsError));
      expect(find.byKey(_selectKey), findsOneWidget);
      expect(await h.checklistLinkRepo.getForPact(_pactId), isNull);
    });

    testWidgets(
        'change_replaces_link_and_remove_clears_it: Change swaps the checklist, Remove unlinks without relocking',
        (tester) async {
      final showup = buildShowup(id: _showupId, pactId: _pactId, scheduledAt: DateTime(2099, 6, 15, 8, 0));
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: [..._clock, showupDetailNowProvider.overrideWithValue(_testNow)],
        beforePump: (h) async {
          await h.pactRepo.savePact(_activePact);
          await h.showupRepo.saveShowups([showup]);
          await h.checklistLinkRepo.upsert(_link('c1', 'Morning'));
        },
      );

      // 2. Change -> Checklister opens -> selecting c2 swaps the link.
      await _openDetail(tester, 'Meditate');
      await _scrollTo(tester, _pactId, find.byKey(_changeKey));
      expect(find.text('Morning'), findsOneWidget);
      await tester.tap(find.byKey(_changeKey));
      await tester.pumpAndSettle();
      expect(h.checklister.launchedUrls.single.host, 'select');
      h.incomingLinks.emit(_selectionCallback('status=selected&checklistId=c2&checklistName=Evening'));
      await waitFor(tester, find.text('Evening'));
      await tester.pumpAndSettle(); // let the old -> new crossfade finish
      expect((await h.checklistLinkRepo.getForPact(_pactId))?.checklistId, 'c2');
      final linked = h.analytics.loggedEvents.whereType<PactChecklistLinkedEvent>().single;
      expect(linked.mode, 'change');

      // 4-5. Remove: no confirmation dialog, back to "Select checklist".
      await tester.tap(find.byKey(_removeKey));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_selectKey), findsOneWidget);
      expect(await h.checklistLinkRepo.getForPact(_pactId), isNull);
      expect(h.analytics.loggedEvents.whereType<PactChecklistUnlinkedEvent>(), hasLength(1));

      // 6. The showup is still markable after the unlink (nothing relocks).
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Meditate'));
      await tester.tap(find.text('Meditate').first);
      await waitFor(tester, find.text(l10n(tester).markDone));
    });

    testWidgets('no_checklist_section_for_inactive_pact: stopped and completed pacts have no Checklist section',
        (tester) async {
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async {
          await h.pactRepo.savePact(buildPact(
            id: 'stopped-pact',
            habitName: 'Stopped Habit',
            startDate: DateTime(2099, 1, 1),
            endDate: DateTime(2099, 3, 31),
            status: PactStatus.stopped,
            stoppedAt: DateTime(2099, 3, 1),
          ));
          await h.pactRepo.savePact(buildPact(
            id: 'completed-pact',
            habitName: 'Completed Habit',
            startDate: DateTime(2099, 1, 1),
            endDate: DateTime(2099, 3, 31),
            status: PactStatus.completed,
          ));
        },
      );

      for (final entry in {'Stopped Habit': 'stopped-pact', 'Completed Habit': 'completed-pact'}.entries) {
        await _openDetail(tester, entry.key);
        await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(find.byKey(_selectKey), findsNothing, reason: entry.key);
        expect(find.text(l10n(tester).pactChecklistSectionTitle.toUpperCase()), findsNothing, reason: entry.key);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  });
}
