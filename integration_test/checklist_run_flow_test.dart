// Scenarios for GH-464: running a linked Checklister checklist before marking a showup done.
//
// Run with: flutter test integration_test/checklist_run_flow_test.dart -d <device>
// Run on host: flutter test integration_test/checklist_run_flow_test.dart
//
// Remaining stubs are filled in WU6 (run-finished callback, late finish, cold start).
// Run callbacks always carry both ids: habitloop://checklist/run-finished?pactId=<id>&showupId=<id>.
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

final _testNow = DateTime(2099, 6, 15, 7, 55);

const _flagOn = {'checklister_integration_enabled': true};

const _pactId = 'checklist-run-pact';
const _showupId = '${_pactId}_20990615T080000_0';
const _runKey = Key('showup-run-checklist-button');
const _changeKey = Key('pact-checklist-change-button');

final _pact = buildPact(id: _pactId, habitName: 'Meditate', startDate: DateTime(2099, 6, 1));
final _pendingShowup = buildShowup(id: _showupId, pactId: _pactId, scheduledAt: DateTime(2099, 6, 15, 8, 0));
final _link =
    PactChecklistLink(pactId: _pactId, checklistId: 'c1', checklistName: 'Morning', linkedAt: DateTime(2099, 6, 1));

List<Override> get _clock => [
      todayProvider.overrideWithValue(_testNow),
      pactDetailNowProvider.overrideWithValue(_testNow),
      pactTimelineNowProvider.overrideWithValue(_testNow),
      showupDetailNowProvider.overrideWithValue(_testNow),
    ];

/// Opens today's showup from the dashboard.
Future<void> _openShowup(WidgetTester tester) async {
  await waitFor(tester, find.text('Meditate'));
  await tester.tap(find.text('Meditate').first);
  await waitFor(tester, find.text(l10n(tester).markFailed));
}

/// Backgrounds and resumes the app. The install watcher throttles re-checks to
/// once per 5 s of wall-clock time, so real time must pass first.
Future<void> _resume(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5100)));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

/// Opens pact detail from the pacts panel and scrolls to the bottom.
Future<void> _openPactDetailBottom(WidgetTester tester) async {
  await openPactsPanel(tester);
  await openPactDetail(tester, 'Meditate');
  await waitFor(tester, find.text(l10n(tester).sectionStats.toUpperCase()));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, Finder finder) {
  final w = tester.widget(finder);
  if (w is ButtonStyleButton) return w.onPressed != null;
  return (w as CupertinoButton).onPressed != null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Checklist run flow', () {
    // Nullable: the WU6 stubs below create no harness yet.
    AppHarness? harness;
    tearDown(() async {
      harness?.dispose();
      harness = null;
    });
    testWidgets(
        'linked_pact_gates_mark_done_behind_run_checklist: linked pact shows Run checklist instead of Mark as done',
        (tester) async {
      final h = harness = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.showupRepo.saveShowups([_pendingShowup]);
          await h.checklistLinkRepo.upsert(_link);
        },
      );
      final strings = l10n(tester);

      // 1-2. Run checklist and Mark as failed; no Mark as done.
      await _openShowup(tester);
      await waitFor(tester, find.byKey(_runKey));
      expect(find.text(strings.markDone), findsNothing);

      // 3. Tapping it opens Checklister's run with our callback carrying both ids.
      await tester.tap(find.byKey(_runKey));
      await tester.pumpAndSettle();
      final launched = h.checklister.launchedUrls.single;
      expect([launched.scheme, launched.host, launched.queryParameters['checklistId']], ['checklister', 'run', 'c1']);
      final callback = Uri.parse(launched.queryParameters['callbackUrl']!);
      expect(callback.toString(), ChecklisterLinks.runFinishedCallback(_pactId, _showupId).toString());
      expect([callback.queryParameters['pactId'], callback.queryParameters['showupId']], [_pactId, _showupId]);

      // 4. Unfinished run recorded; checklist_run_started fired.
      final run = await h.checklistRunRepo.getForShowup(_showupId);
      expect([run?.checklistId, run?.isFinished], ['c1', false]);
      final started = h.analytics.loggedEvents.whereType<ChecklistRunStartedEvent>().single;
      expect(started.pactId, _pactId);

      // 5. No callback (the user just comes back): still gated.
      await _resume(tester);
      expect(find.byKey(_runKey), findsOneWidget);
      expect(find.text(strings.markDone), findsNothing);
    });

    testWidgets(
        'completed_run_unlocks_mark_done_and_persists: completed callback unlocks Mark as done and survives reopen',
        (tester) async {
      // TODO: 1. Seed as in the gate scenario; tap Run checklist.
      // TODO: 2. Emit run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 3. Showup detail shows "Mark as done", no failure dialog; checklist_run_finished fired.
      // TODO: 4. Navigate back, reopen the showup: "Mark as done" still shown.
      // TODO: 5. Tap Mark as done.
      // TODO: 6. Showup is done; showup_marked_done carries checklist_outcome=success.
    });

    testWidgets('unsuccessful_run_shows_dialog_and_unlocks: cancelled and error both show the dialog and unlock',
        (tester) async {
      // TODO: 1. Seed as in the gate scenario; tap Run checklist.
      // TODO: 2. Emit run-finished?pactId=<id>&showupId=<id>&status=cancelled: unsuccessful-run dialog shown.
      // TODO: 3. Tap OK: "Mark as done" shown.
      // TODO: 4. Reopen the showup: still unlocked, dialog not shown again.
      // TODO: 5. Repeat with a second showup using status=error: dialog shown and unlocked.
      // TODO: 6. Mark one done: showup_marked_done carries checklist_outcome=failure.
    });

    testWidgets('late_finish_within_grace_prevents_auto_fail: run finished within 15 minutes after the window closes',
        (tester) async {
      // TODO: 1. Seed a linked pact and a showup at 08:00 with a 10-minute duration.
      // TODO: 2. Use a mutable showupDetailNowProvider clock at 08:05; open the showup and tap Run checklist.
      // TODO: 3. Advance the clock to 08:20 (window closed 08:10, inside the 15-minute grace).
      // TODO: 4. Emit run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 5. Showup is still pending (not auto-failed); "Mark as done" shown.
      // TODO: 6. Tap Mark as done: showup marked done.
      // TODO: 7. Variant: clock at 08:30 with a started run; reopening the showup auto-fails it (past grace).
    });

    testWidgets('redeeming_auto_failed_showup_ignores_checklist_gate: redemption needs only the note', (tester) async {
      const failedId = '${_pactId}_20990614T080000_0';
      final h = harness = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          // Note pre-seeded: typing is covered by redeem_showup_flow_test and is flaky on CI's IME.
          await h.showupRepo.saveShowup(buildShowup(
            id: failedId,
            pactId: _pactId,
            scheduledAt: DateTime(2099, 6, 14, 8, 0),
            status: ShowupStatus.failed,
            note: 'Did it, forgot to tap',
          ));
          await h.checklistLinkRepo.upsert(_link);
        },
      );
      final strings = l10n(tester);

      // 1-2. Open the auto-failed showup from the timeline.
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Meditate');
      // Keyed scroll view: openTimeline's bare ListView finder also matches the pacts panel here.
      const timelineButton = Key('pact-detail-timeline-button');
      await tester.dragUntilVisible(
        find.byKey(timelineButton),
        find.byKey(const Key('pact-detail-scroll-view-$_pactId')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(timelineButton));
      await tester.pumpAndSettle();
      const tile = Key('timeline-milestone-$failedId');
      await waitFor(tester, find.byKey(tile));
      await tester.tap(find.byKey(tile));
      await waitFor(tester, find.byKey(const Key('showup-redeem-button')));

      // 3. No Run checklist; redemption is enabled by the note alone.
      expect(find.byKey(_runKey), findsNothing);
      expect(_enabled(tester, find.byKey(const Key('showup-redeem-button'))), isTrue);

      // 4-5. Redeem: done, and no run was ever needed.
      await tester.tap(find.byKey(const Key('showup-redeem-button')));
      await waitFor(tester, find.text(strings.showupDone));
      expect((await h.showupRepo.getShowupById(failedId))?.status, ShowupStatus.done);
      expect(await h.checklistRunRepo.getForShowup(failedId), isNull);
      expect(h.checklister.launchedUrls, isEmpty);
    });

    testWidgets('checklister_install_state_switches_gate_on_resume: install state change on resume toggles the gate',
        (tester) async {
      final h = harness = await AppHarness.create(
        tester,
        remoteConfigOverrides: _flagOn,
        extraOverrides: _clock,
        beforePump: (h) async {
          h.checklister.installed = false;
          await h.pactRepo.savePact(_pact);
          await h.showupRepo.saveShowups([_pendingShowup]);
          await h.checklistLinkRepo.upsert(_link);
        },
      );
      final strings = l10n(tester);

      // 2. Pact detail: no Checklist section.
      await _openPactDetailBottom(tester);
      expect(find.byKey(_changeKey), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 3. Showup detail: plain Mark as done.
      await _openShowup(tester);
      expect(find.text(strings.markDone), findsOneWidget);
      expect(find.byKey(_runKey), findsNothing);

      // 4-5. Installed while backgrounded: the open showup re-gates; the pact shows its link.
      h.checklister.installed = true;
      await _resume(tester);
      await waitFor(tester, find.byKey(_runKey));
      expect(find.text(strings.markDone), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openPactDetailBottom(tester);
      await waitFor(tester, find.text('Morning'));
      expect(find.byKey(_changeKey), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 6-7. Uninstalled again: Mark as done is back and the link is kept.
      h.checklister.installed = false;
      await _resume(tester);
      await _openShowup(tester);
      expect(find.text(strings.markDone), findsOneWidget);
      expect(find.byKey(_runKey), findsNothing);
      expect(await h.checklistLinkRepo.getForPact(_pactId), isNotNull);
    });

    testWidgets('cold_start_callback_opens_showup_detail: initial link opens the showup detail screen', (tester) async {
      // TODO: 1. Seed a linked pact, a pending showup and an unfinished run record.
      // TODO: 2. Create the harness with incomingLinks.initialLink =
      //          habitloop://checklist/run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 3. Pump to the first frame.
      // TODO: 4. Showup detail for that showup is on top of the dashboard.
      // TODO: 5. "Mark as done" shown; run marked finished in the repo; back returns to the dashboard.
    });
  });
}
