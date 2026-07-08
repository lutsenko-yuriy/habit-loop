// Integration tests for the showup redemption flow (HAB-139).
//
// Run on host:   flutter test integration_test/redeem_showup_flow_test.dart
// Run on device: flutter test integration_test/redeem_showup_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

bool _redeemEnabled(WidgetTester tester) {
  final w = tester.widget(find.byKey(const Key('showup-redeem-button')));
  if (w is ButtonStyleButton) return w.onPressed != null;
  return (w as CupertinoButton).onPressed != null;
}

// Dashboard and timeline anchored on June 15 2099.
// Default 7-day tail → cutoff = June 8.
// showup on June 14 is 1 day old → in-tail.
final _timelineNow = DateTime(2099, 6, 15, 7, 55);

// For the out-of-tail scenario: detail screen sees now = July 15 2099.
// Tail cutoff becomes July 8 → June 14 showup (31 days ago) is out of tail.
final _detailNowOutOfTail = DateTime(2099, 7, 15, 7, 55);

const _pactId = 'redeem-test-pact';
final _pact = Pact(
  id: _pactId,
  habitName: 'Morning Run',
  startDate: DateTime(2099, 6, 1),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: DateTime(2099, 6, 1),
);

// 1 day before _timelineNow — within the 7-day tail zone on June 15.
// June 14 is the latest seeded date, so the dashboard's gap-fill generates
// June 15+ only and auto-fails nothing — keeping Failed=0 after redemption.
const _showupId = 'redeem-showup-in-tail';
final _showupAt = DateTime(2099, 6, 14, 8, 0);

Future<void> _openShowupDetailFromTimeline(WidgetTester tester, String showupId) async {
  final tileKey = Key('timeline-milestone-$showupId');
  await waitFor(tester, find.byKey(tileKey));
  await tester.tap(find.byKey(tileKey));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Redeem showup flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'redeem_auto_failed_showup_with_note_succeeds: redemption marks showup done, updates stats, and fires showup_redeemed',
      (tester) async {
        final showup = Showup(
          id: _showupId,
          pactId: _pactId,
          scheduledAt: _showupAt,
          duration: const Duration(minutes: 10),
          status: ShowupStatus.failed,
          redeemable: true,
          note: 'I was there, app was offline',
        );

        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_timelineNow),
            pactDetailNowProvider.overrideWithValue(_timelineNow),
            pactTimelineNowProvider.overrideWithValue(_timelineNow),
            showupDetailNowProvider.overrideWithValue(_timelineNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowup(showup);
          },
        );

        final strings = l10n(tester);

        // ── 1. Navigate to showup detail via timeline ─────────────────────────
        await openPactsPanel(tester);
        await openPactDetail(tester, 'Morning Run');
        await openTimeline(tester);
        await _openShowupDetailFromTimeline(tester, _showupId);

        await waitFor(tester, find.text(strings.showupDetailTitle));

        // ── 2. Redemption button is visible and enabled ────────────────────────
        await waitFor(tester, find.byKey(const Key('showup-redeem-button')));
        expect(_redeemEnabled(tester), isTrue);

        // ── 3. Tap the redemption button ───────────────────────────────────────
        await tester.tap(find.byKey(const Key('showup-redeem-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // ── 4. Status chip shows "Done" ────────────────────────────────────────
        await waitFor(tester, find.text(strings.showupDone));
        expect(find.text(strings.showupDone), findsOneWidget);

        // ── 5. showup_redeemed analytics event fired with correct pact_id ──────
        expect(
          h.analytics.loggedEvents.any((e) => e.name == 'showup_redeemed'),
          isTrue,
        );
        final redeemed = h.analytics.loggedEvents.firstWhere((e) => e.name == 'showup_redeemed');
        expect(redeemed.toParameters()['pact_id'], _pactId);

        // ── 6. Verify done/failed counts persisted ────────────────────────────
        // redeemShowup() calls persistShowupStatus → _syncStatsBestEffort →
        // persistStats → writes updated pact.stats to the repository.
        // Reading the repository directly avoids fragile UI widget-tree traversal.
        final pactAfter = await h.pactRepo.getPactById(_pactId);
        expect(pactAfter?.stats?.showupsDone, 1);
        expect(pactAfter?.stats?.showupsFailed, 0);
      },
    );

    testWidgets(
      'redemption_button_disabled_when_note_is_empty: button visible but disabled with explanatory label; fires showup_redemption_blocked on screen load',
      (tester) async {
        final showup = Showup(
          id: _showupId,
          pactId: _pactId,
          scheduledAt: _showupAt,
          duration: const Duration(minutes: 10),
          status: ShowupStatus.failed,
          redeemable: true,
          // no note
        );

        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_timelineNow),
            pactDetailNowProvider.overrideWithValue(_timelineNow),
            pactTimelineNowProvider.overrideWithValue(_timelineNow),
            showupDetailNowProvider.overrideWithValue(_timelineNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowup(showup);
          },
        );

        final strings = l10n(tester);

        // ── 1. Navigate to showup detail via timeline ─────────────────────────
        await openPactsPanel(tester);
        await openPactDetail(tester, 'Morning Run');
        await openTimeline(tester);
        await _openShowupDetailFromTimeline(tester, _showupId);

        await waitFor(tester, find.text(strings.showupDetailTitle));
        await waitFor(tester, find.byKey(const Key('showup-redeem-button')));

        // ── 2. Redemption button is visible but disabled ───────────────────────
        expect(_redeemEnabled(tester), isFalse);

        // ── 3. Explanatory hint is shown ──────────────────────────────────────
        expect(find.text(strings.showupRedeemAddNoteHint), findsOneWidget);

        // ── 4. Status chip still shows "Failed" ───────────────────────────────
        // findsAtLeastNWidgets because the timeline tile behind the Nav stack
        // also renders "Failed".
        expect(find.text(strings.showupFailed), findsAtLeastNWidgets(1));

        // ── 5. showup_redemption_blocked fired on screen load ─────────────────
        expect(
          h.analytics.loggedEvents.any((e) => e.name == 'showup_redemption_blocked'),
          isTrue,
        );
      },
    );

    testWidgets(
      'no_redemption_action_for_manually_failed_showup: redeemable=false hides the redemption button entirely',
      (tester) async {
        final showup = Showup(
          id: _showupId,
          pactId: _pactId,
          scheduledAt: _showupAt,
          duration: const Duration(minutes: 10),
          status: ShowupStatus.failed,
          redeemable: false, // manually failed
        );

        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_timelineNow),
            pactDetailNowProvider.overrideWithValue(_timelineNow),
            pactTimelineNowProvider.overrideWithValue(_timelineNow),
            showupDetailNowProvider.overrideWithValue(_timelineNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowup(showup);
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Morning Run');
        await openTimeline(tester);
        await _openShowupDetailFromTimeline(tester, _showupId);

        await waitFor(tester, find.text(strings.showupDetailTitle));
        await tester.pump(const Duration(milliseconds: 200));

        // ── Redemption button is absent ────────────────────────────────────────
        expect(find.byKey(const Key('showup-redeem-button')), findsNothing);
      },
    );

    testWidgets(
      'no_redemption_action_for_out_of_tail_zone_showup: showup older than N days hides the redemption button',
      (tester) async {
        // The same showup appears in the timeline's tail zone from _timelineNow
        // (June 15 — 2 days after June 13 → within 7-day window → individual tile).
        // But the showup detail screen uses _detailNowOutOfTail (July 15), where
        // the same showup is 32 days old and outside the 7-day tail.
        // This lets us navigate via the timeline while verifying the VM correctly
        // gates canRedeem on the detail-screen's "now", not the timeline's "now".
        final showup = Showup(
          id: _showupId,
          pactId: _pactId,
          scheduledAt: _showupAt,
          duration: const Duration(minutes: 10),
          status: ShowupStatus.failed,
          redeemable: true,
        );

        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_timelineNow),
            pactDetailNowProvider.overrideWithValue(_timelineNow),
            pactTimelineNowProvider.overrideWithValue(_timelineNow),
            // Detail screen uses a later "now" so the showup falls outside tail.
            showupDetailNowProvider.overrideWithValue(_detailNowOutOfTail),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowup(showup);
          },
        );

        final strings = l10n(tester);

        // Navigate via timeline (June 15 "now" → June 13 is in-tail → individual tile).
        await openPactsPanel(tester);
        await openPactDetail(tester, 'Morning Run');
        await openTimeline(tester);
        await _openShowupDetailFromTimeline(tester, _showupId);

        await waitFor(tester, find.text(strings.showupDetailTitle));
        await tester.pump(const Duration(milliseconds: 200));

        // ── Redemption button is absent because canRedeem=false ────────────────
        // VM uses _detailNowOutOfTail (July 15): cutoff = July 8, June 13 < July 8 → out of tail.
        expect(find.byKey(const Key('showup-redeem-button')), findsNothing);
      },
    );
  });
}
