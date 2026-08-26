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
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(elapsedBreak);
          await h.showupRepo.saveShowup(postBreakShowup);
          // Nothing pending with the OS — simulates the break-resume bug: the
          // in-window cancel never got followed by a reschedule.
          h.notifications.pendingNotifications = const [];
        },
      );

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
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(activeBreak);
          await h.showupRepo.saveShowup(inWindowShowup);
          await h.showupRepo.saveShowup(welcomeBackShowup);
          // In-window showup's reminder was cancelled when the break started
          // — nothing pending for it. The welcome-back showup's reminder was
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
        },
      );

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
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(elapsedBreak);
          await h.showupRepo.saveShowup(postBreakShowup);
          h.notifications.pendingNotifications = const [];
        },
      );

      // No foreground event fired — pullCompleted is the sole trigger here.
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
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowup(showup);
          // Already correctly scheduled — matches the desired plan exactly.
          h.notifications.pendingNotifications = [
            PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-1')),
          ];
        },
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      final scheduledCountAfterFirst = h.notifications.scheduledReminders.length;
      final cancelledCountAfterFirst = h.notifications.cancelledShowupIds.length;

      // A second resumed event without an intervening paused one — pumping
      // while AppLifecycleState.paused hangs LiveTestWidgetsFlutterBinding on
      // host (it deliberately withholds real frames while backgrounded), and
      // the throttle/idempotence behaviour under test doesn't depend on the
      // pause actually happening.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders.length, equals(scheduledCountAfterFirst));
      expect(h.notifications.cancelledShowupIds.length, equals(cancelledCountAfterFirst));
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
      // scheduling pass.
      h.notifications.reset();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(h.notifications.scheduledReminders, isEmpty);
      expect(h.notifications.cancelledShowupIds, isEmpty);
    });
  });
}
