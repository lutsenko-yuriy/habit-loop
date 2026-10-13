// Scenarios for GH-464: running a linked Checklister checklist before marking a showup done.
//
// Run with: flutter test integration_test/checklist_run_flow_test.dart -d <device>
// Run on host: flutter test integration_test/checklist_run_flow_test.dart
//
// Run callbacks always carry both ids: habitloop://checklist/run-finished?pactId=<id>&showupId=<id>.
import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/navigation/notification_navigator.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

import 'harness.dart';
import 'harness_binding.dart';

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

/// A test clock that can move forward mid-scenario.
class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  static final _providers = [todayProvider, pactDetailNowProvider, pactTimelineNowProvider, showupDetailNowProvider];

  List<Override> get overrides => [for (final p in _providers) p.overrideWith((ref) => now)];

  /// Moves to [time]; screens and sweeps see it on their next load.
  void advanceTo(WidgetTester tester, DateTime time) {
    now = time;
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    for (final p in _providers) {
      container.invalidate(p);
    }
  }
}

/// Re-runs the dashboard load (and its auto-fail sweep), as a resume does.
void _bumpDashboardRefresh(WidgetTester tester) {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(dashboardRefreshSignalProvider.notifier)
      .state++;
}

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

/// Delivers Checklister's run-finished callback for [showupId] with [status].
Future<void> _finishRun(WidgetTester tester, AppHarness h, String status, {String showupId = _showupId}) async {
  h.incomingLinks.emit(_runFinished(status, showupId: showupId));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

Uri _runFinished(String status, {String showupId = _showupId}) =>
    Uri.parse('${ChecklisterLinks.runFinishedCallback(_pactId, showupId)}&status=$status&checklistId=c1&runId=r1');

Future<AppHarness> _linkedHarness(
  WidgetTester tester, {
  Future<void> Function(AppHarness h)? seed,
  _MutableClock? clock,
}) =>
    AppHarness.create(
      tester,
      remoteConfigOverrides: _flagOn,
      extraOverrides: clock?.overrides ?? _clock,
      beforePump: (h) async {
        await h.pactRepo.savePact(_pact);
        await h.showupRepo.saveShowups([_pendingShowup]);
        await h.checklistLinkRepo.upsert(_link);
        await seed?.call(h);
      },
    );

bool _enabled(WidgetTester tester, Finder finder) {
  final w = tester.widget(finder);
  if (w is ButtonStyleButton) return w.onPressed != null;
  return (w as CupertinoButton).onPressed != null;
}

void main() {
  HarnessBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Checklist run flow', () {
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
      final h = harness = await _linkedHarness(tester);
      final strings = l10n(tester);

      // 1. Tap Run checklist.
      await _openShowup(tester);
      await waitFor(tester, find.byKey(_runKey));
      await tester.tap(find.byKey(_runKey));
      await tester.pumpAndSettle();

      // 2-3. Completed callback: Mark as done shown in place, no dialog; checklist_run_finished fired.
      await _finishRun(tester, h, 'completed');
      await waitFor(tester, find.text(strings.markDone));
      expect(find.byKey(_runKey), findsNothing);
      expect(find.text(strings.showupChecklistFailedTitle), findsNothing);
      final finished = h.analytics.loggedEvents.whereType<ChecklistRunFinishedEvent>().single;
      expect(finished.outcome, ChecklistRunOutcome.success);

      // 4. Back, reopen: still unlocked.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openShowup(tester);
      expect(find.text(strings.markDone), findsOneWidget);
      expect(find.byKey(_runKey), findsNothing);

      // 5-6. Mark as done: done, with checklist_outcome=success.
      await tester.tap(find.text(strings.markDone));
      await waitFor(tester, find.text(strings.showupDone));
      expect((await h.showupRepo.getShowupById(_showupId))?.status, ShowupStatus.done);
      final done = h.analytics.loggedEvents.whereType<ShowupMarkedDoneEvent>().single;
      expect(done.toParameters()['checklist_outcome'], 'success');
    });

    testWidgets('unsuccessful_run_shows_dialog_and_unlocks: cancelled and error both show the dialog and unlock',
        (tester) async {
      const secondId = '${_pactId}_20990615T075000_0';
      final h = harness = await _linkedHarness(
        tester,
        seed: (h) async {
          // Window 07:50–08:00 is open at 07:55; its run was started earlier.
          await h.showupRepo.saveShowup(
            buildShowup(id: secondId, pactId: _pactId, scheduledAt: DateTime(2099, 6, 15, 7, 50)),
          );
          await h.checklistRunRepo
              .upsertStarted(showupId: secondId, pactId: _pactId, checklistId: 'c1', startedAt: _testNow);
        },
      );
      final strings = l10n(tester);

      // 1. Tap Run checklist on the 08:00 showup (opened by id: both tiles read "Meditate").
      await waitFor(tester, find.text('Meditate'));
      unawaited(NotificationNavigator.navigateToShowup(navigatorKey: h.navigatorKey, showupId: _showupId));
      await waitFor(tester, find.byKey(_runKey));
      await tester.tap(find.byKey(_runKey));
      await tester.pumpAndSettle();

      // 2-3. Cancelled: dialog; OK unlocks Mark as done.
      await _finishRun(tester, h, 'cancelled');
      await waitFor(tester, find.text(strings.showupChecklistFailedTitle));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(strings.showupChecklistFailedTitle), findsNothing);
      expect(find.text(strings.markDone), findsOneWidget);

      // 4. Reopen: still unlocked, no second dialog.
      await tester.pageBack();
      await tester.pumpAndSettle();
      unawaited(NotificationNavigator.navigateToShowup(navigatorKey: h.navigatorKey, showupId: _showupId));
      await waitFor(tester, find.text(strings.markDone));
      expect(find.text(strings.showupChecklistFailedTitle), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 5. Error for the other showup (no screen open): its detail opens with the dialog, unlocked.
      await _finishRun(tester, h, 'error', showupId: secondId);
      await waitFor(tester, find.text(strings.showupChecklistFailedTitle));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(strings.markDone), findsOneWidget);

      // 6. Mark it done: checklist_outcome=failure.
      await tester.tap(find.text(strings.markDone));
      await waitFor(tester, find.text(strings.showupDone));
      expect((await h.showupRepo.getShowupById(secondId))?.status, ShowupStatus.done);
      final done = h.analytics.loggedEvents.whereType<ShowupMarkedDoneEvent>().single;
      expect(done.toParameters()['checklist_outcome'], 'failure');
      expect(h.analytics.loggedEvents.whereType<ChecklistRunFinishedEvent>(), hasLength(2));
    });

    testWidgets('late_finish_within_grace_prevents_auto_fail: run finished within 15 minutes after the window closes',
        (tester) async {
      // 1. Linked pact; showup window 08:00–08:10; clock at 08:05.
      final clock = _MutableClock(DateTime(2099, 6, 15, 8, 5));
      final h = harness = await _linkedHarness(tester, clock: clock);
      final strings = l10n(tester);

      // 2. Open the showup and start the run inside the window.
      await _openShowup(tester);
      await tester.tap(find.byKey(_runKey));
      await tester.pumpAndSettle();
      expect(await h.checklistRunRepo.getForShowup(_showupId), isNotNull);

      // 3. The window closes; back on the dashboard at 08:20 (inside the grace) the sweep skips it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      clock.advanceTo(tester, DateTime(2099, 6, 15, 8, 20));
      _bumpDashboardRefresh(tester);
      await tester.pumpAndSettle();
      expect((await h.showupRepo.getShowupById(_showupId))?.status, ShowupStatus.pending);

      // 4–5. The completed callback opens the showup: still pending, Mark as done shown.
      await _finishRun(tester, h, 'completed');
      await waitFor(tester, find.text(strings.markDone));
      expect((await h.showupRepo.getShowupById(_showupId))?.status, ShowupStatus.pending);

      // 6. Mark as done.
      await tester.tap(find.text(strings.markDone));
      await waitFor(tester, find.text(strings.showupDone));
      expect((await h.showupRepo.getShowupById(_showupId))?.status, ShowupStatus.done);
    });

    testWidgets('late_finish_past_grace_auto_fails: a started run no longer protects the showup after 15 minutes',
        (tester) async {
      // 7. Run started at 08:05; clock at 08:26 (grace ended 08:25): the showup is auto-failed.
      final h = harness = await _linkedHarness(
        tester,
        clock: _MutableClock(DateTime(2099, 6, 15, 8, 26)),
        seed: (h) => h.checklistRunRepo.upsertStarted(
          showupId: _showupId,
          pactId: _pactId,
          checklistId: 'c1',
          startedAt: DateTime(2099, 6, 15, 8, 5),
        ),
      );
      await waitFor(tester, find.text('Meditate'));
      expect((await h.showupRepo.getShowupById(_showupId))?.status, ShowupStatus.failed);
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
      // 1-3. A started run, and the callback is already waiting when the app starts.
      final h = harness = await _linkedHarness(
        tester,
        seed: (h) async {
          await h.checklistRunRepo
              .upsertStarted(showupId: _showupId, pactId: _pactId, checklistId: 'c1', startedAt: _testNow);
          h.incomingLinks.emit(_runFinished('completed'));
        },
      );
      final strings = l10n(tester);

      // 4-5. Showup detail on top, unlocked; the run is finished; back returns to the dashboard.
      await waitFor(tester, find.text(strings.markDone));
      expect(find.byKey(_runKey), findsNothing);
      expect((await h.checklistRunRepo.getForShowup(_showupId))?.isFinished, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(strings.markDone), findsNothing);
      await waitFor(tester, find.text('Meditate'));
    });
  });
}
