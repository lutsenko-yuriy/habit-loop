// Integration tests for notification reconciliation sync (HAB-254): a
// stateless desired-vs-actual diff that catches drift between derived pact
// state (on-break status, etc.) and actually-scheduled OS notifications,
// triggered on app foreground and on Firestore sync-pull completion.
//
// Run on host:   flutter test integration_test/notification_reconciliation_flow_test.dart
// Run on device: flutter test integration_test/notification_reconciliation_flow_test.dart -d <device>
import 'package:flutter/widgets.dart' show AppLifecycleState, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';
import 'package:habit_loop/slices/reminder/application/reconciliation_throttle.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Pumps a handful of frames so the async chain triggered by a
/// reconciliation pass (repository reads, notification-service calls) has a
/// chance to complete — there is no widget to `waitFor` here since the
/// reconciler renders nothing.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// `AppLifecycleReconciler` also fires a one-shot reconcile() on cold start
/// (post-frame, HAB-254 WU3 audit fix) in addition to its two named
/// triggers — so every harness boot already runs one reconciliation pass
/// before a test gets to drive anything explicitly. Scenarios that want to
/// isolate a *specific* trigger override the throttle to a zero interval
/// (so the cold-start pass never blocks the trigger under test) and call
/// `h.notifications.reset()` after harness creation (so the cold-start
/// pass's own effects don't pollute the assertion).
final _zeroIntervalThrottle =
    reconciliationThrottleProvider.overrideWithValue(ReconciliationThrottle(minInterval: Duration.zero));

/// Makes `FakeNotificationService.pendingNotifications` reflect every call
/// recorded so far, the way a real OS's pending list would after those calls
/// actually landed — the fake does not do this automatically. Needed to test
/// genuine idempotence across two *real* (non-throttled) reconcile() runs:
/// without this, a second run keeps "discovering" every notification the
/// first run scheduled as still missing and re-schedules it, which looks
/// like non-idempotence but is actually just the fake's static list never
/// having caught up (not a production bug — audit finding, PR #412).
void _syncPendingFromRecordedCalls(AppHarness h) {
  // cancelShowupReminder cancels all three kinds for a showup at once — a
  // showup with any cancellation call recorded is no longer pending at all,
  // even if an earlier scheduling call for it is also on record.
  final cancelledIds = h.notifications.cancelledShowupIds.toSet();
  h.notifications.pendingNotifications = [
    for (final r in h.notifications.scheduledReminders)
      if (!cancelledIds.contains(r.showup.id))
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId(r.showup.id)),
    for (final d in h.notifications.scheduledDeadlines)
      if (!cancelledIds.contains(d.showup.id))
        PendingNotificationInfo(id: NotificationConstants.deadlineNotificationId(d.showup.id)),
    for (final hu in h.notifications.scheduledHurryUps)
      if (!cancelledIds.contains(hu.showup.id))
        PendingNotificationInfo(id: NotificationConstants.hurryUpNotificationId(hu.showup.id)),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Notification reconciliation sync', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('break_end_elapsed_restores_reminders_on_foreground', (tester) async {
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final elapsedBreak = buildBreak(
        id: 'brk-1',
        pactId: 'pact-1',
        startDate: now.subtract(const Duration(days: 10)),
        plannedEndDate: now.subtract(const Duration(days: 1)),
      );
      final postBreakShowup = buildShowup(
        id: 'su-post-break',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 1)),
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [_zeroIntervalThrottle],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(elapsedBreak);
          await h.showupRepo.saveShowup(postBreakShowup);
          // Nothing pending with the OS — simulates the break-resume bug: the
          // in-window cancel never got followed by a reschedule.
          h.notifications.pendingNotifications = const [];
        },
      );
      // Isolate the explicit trigger below from the cold-start pass that
      // already ran once during harness creation.
      h.notifications.reset();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders.any((r) => r.showup.id == 'su-post-break'), isTrue);
    });

    testWidgets('active_break_keeps_reminders_cancelled_on_foreground', (tester) async {
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final activeBreak = buildBreak(
        id: 'brk-1',
        pactId: 'pact-1',
        startDate: now.subtract(const Duration(days: 2)),
        plannedEndDate: now.add(const Duration(days: 2)),
      );
      final inWindowShowup = buildShowup(
        id: 'su-inwindow',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(hours: 1)),
      );
      final welcomeBackShowup = buildShowup(
        id: 'su-welcome-back',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 3)),
      );
      final welcomeBackText = NotificationTextBuilder.buildWelcomeBackText(
        habitName: 'Meditate',
        l10n: lookupAppLocalizations(const Locale('en')),
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [_zeroIntervalThrottle],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(activeBreak);
          await h.showupRepo.saveShowup(inWindowShowup);
          await h.showupRepo.saveShowup(welcomeBackShowup);
        },
      );
      // Isolate the explicit trigger below from the cold-start pass that
      // already ran once during harness creation.
      h.notifications.reset();
      // In-window showup's reminder was cancelled when the break started —
      // nothing pending for it. The welcome-back showup's reminder was
      // already proactively scheduled by PactBreakService.startBreak.
      h.notifications.pendingNotifications = [
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-welcome-back')),
      ];
      h.notifications.scheduledReminders.add((
        showup: welcomeBackShowup,
        pact: pact,
        titleText: welcomeBackText.title,
        bodyText: welcomeBackText.body,
      ));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders.any((r) => r.showup.id == 'su-inwindow'), isFalse);
      expect(h.notifications.cancelledShowupIds, isEmpty);

      final welcomeBackCalls = h.notifications.scheduledReminders.where((r) => r.showup.id == 'su-welcome-back');
      expect(welcomeBackCalls, hasLength(1));
      expect(welcomeBackCalls.single.titleText, equals(welcomeBackText.title));
      expect(welcomeBackCalls.single.bodyText, equals(welcomeBackText.body));
    });

    testWidgets('sync_pull_completion_triggers_reconciliation', (tester) async {
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final elapsedBreak = buildBreak(
        id: 'brk-1',
        pactId: 'pact-1',
        startDate: now.subtract(const Duration(days: 10)),
        plannedEndDate: now.subtract(const Duration(days: 1)),
      );
      final postBreakShowup = buildShowup(
        id: 'su-post-break',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 1)),
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [_zeroIntervalThrottle],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(elapsedBreak);
          await h.showupRepo.saveShowup(postBreakShowup);
          h.notifications.pendingNotifications = const [];
        },
      );
      // Isolate the trigger under test from the cold-start pass that already
      // ran once during harness creation — no explicit foreground event is
      // fired below, so if this assertion passed without the reset() above,
      // it would only be proving the cold-start trigger works, not this one.
      h.notifications.reset();

      h.syncService.emitPullCompleted();
      await _settle(tester);

      expect(h.notifications.scheduledReminders.any((r) => r.showup.id == 'su-post-break'), isTrue);
    });

    testWidgets('reconciliation_is_idempotent_across_repeated_foregrounds', (tester) async {
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final showup = buildShowup(
        id: 'su-1',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 1)),
      );

      h = await AppHarness.create(
        tester,
        // Zero interval so the second trigger below actually runs
        // reconcile() again instead of being throttled — this test asserts
        // real idempotence (an unchanged desired-vs-actual diff makes no
        // further calls), not throttle blocking (covered separately below).
        extraOverrides: [_zeroIntervalThrottle],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowup(showup);
          // Already correctly scheduled — matches the desired plan exactly.
          h.notifications.pendingNotifications = [
            PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-1')),
          ];
        },
      );
      // Closes the loop on the cold-start pass that already ran once during
      // harness creation (also un-throttled) — otherwise its own scheduling
      // calls would immediately look "missing" again to the next trigger.
      _syncPendingFromRecordedCalls(h);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      _syncPendingFromRecordedCalls(h);
      final scheduledCountAfterFirst = h.notifications.scheduledReminders.length;
      final cancelledCountAfterFirst = h.notifications.cancelledShowupIds.length;

      // A second resumed event without an intervening paused one — pumping
      // while AppLifecycleState.paused hangs LiveTestWidgetsFlutterBinding on
      // host (it deliberately withholds real frames while backgrounded), and
      // idempotence doesn't depend on the pause actually happening.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders.length, equals(scheduledCountAfterFirst));
      expect(h.notifications.cancelledShowupIds.length, equals(cancelledCountAfterFirst));
    });

    testWidgets('a second trigger within the throttle interval makes no additional reconcile() call', (tester) async {
      // Uses the *default* (production, 30s) throttle — deliberately not
      // overridden — to prove ReconciliationThrottle actually blocks a rapid
      // repeat trigger, distinct from the idempotence test above (which
      // disables the throttle to test the underlying diff's own
      // idempotence instead).
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final showup = buildShowup(
        id: 'su-1',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 1)),
      );

      h = await AppHarness.create(
        tester,
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowup(showup);
        },
      );
      await _settle(tester);
      // The cold-start pass itself is this test's "first" trigger — it
      // already ran, un-throttled, at mount and consumed the default
      // throttle's 30s slot. su-1 had nothing pending, so it scheduled a
      // reminder for it. Counted by su-1's own id, not scheduledReminders'
      // total length — the dashboard's own concurrent gap-fill pass can add
      // unrelated entries at any point during _settle, which would otherwise
      // move this baseline for reasons unrelated to the throttle under test.
      int su1Count() => h.notifications.scheduledReminders.where((r) => r.showup.id == 'su-1').length;
      final scheduledCountAfterFirst = su1Count();
      expect(scheduledCountAfterFirst, greaterThan(0));

      // An explicit foreground trigger immediately after — well within the
      // 30s interval the cold-start pass already consumed — must be blocked.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(su1Count(), equals(scheduledCountAfterFirst));
    });

    testWidgets('kill_switch_disables_reconciliation', (tester) async {
      final now = DateTime.now();
      final pact = buildPact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: now.subtract(const Duration(days: 30)),
        reminderOffset: const Duration(minutes: 10),
      );
      final elapsedBreak = buildBreak(
        id: 'brk-1',
        pactId: 'pact-1',
        startDate: now.subtract(const Duration(days: 10)),
        plannedEndDate: now.subtract(const Duration(days: 1)),
      );
      final postBreakShowup = buildShowup(
        id: 'su-post-break',
        pactId: 'pact-1',
        scheduledAt: now.add(const Duration(days: 1)),
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {'notification_reconciliation_enabled': false}),
          ),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(elapsedBreak);
          await h.showupRepo.saveShowup(postBreakShowup);
        },
      );
      // The dashboard's own initial load proactively schedules reminders for
      // newly-generated showups regardless of the reconciliation kill switch
      // — reset the recorded calls so the assertion below is scoped to what
      // the (disabled) reconciliation trigger itself does, not that one-shot
      // scheduling pass. The kill switch already made the cold-start pass a
      // no-op, so this reset is purely about the dashboard's own scheduling.
      h.notifications.reset();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders, isEmpty);
      expect(h.notifications.cancelledShowupIds, isEmpty);
    });
  });
}
