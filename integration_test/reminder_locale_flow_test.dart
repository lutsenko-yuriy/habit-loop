// On-device entry point for the reminder-notification-locale flow test.
//
// Run with: flutter test integration_test/reminder_locale_flow_test.dart -d <device>
// Run on host: flutter test integration_test/reminder_locale_flow_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// Fixed clock: reminder-eligible showups are generated for "today" (midnight)
// through +10 days, independent of the real wall-clock time the test runs at.
final _testNow = DateTime(2099, 6, 15, 7, 0);
final _testToday = DateTime(2099, 6, 15);

const _pactId = 'reminder-locale-test-pact-1';

Pact _seedPact() => buildPact(
      id: _pactId,
      habitName: 'Meditate',
      startDate: _testToday,
      reminderOffset: const Duration(minutes: 30),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Reminder locale flow', () {
    // TODO: restore late AppHarness h; tearDown(() => h.dispose());

    testWidgets(
        'schedules_reminder_in_device_locale_without_in_app_override: reminder notifications use the device/system locale when no in-app language override has ever been saved',
        (tester) async {
      // 1. Launch the app with the device/system locale set to Russian and no in-app locale preference ever saved.
      final h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          deviceLocaleProvider.overrideWithValue(const Locale('ru')),
        ],
        // 2. Seed an active pact with a reminder offset and no showups yet (dashboard's first-load sweep generates and schedules them).
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedPact());
        },
      );
      addTearDown(h.dispose);

      // 3. Load the dashboard.
      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.pump(const Duration(milliseconds: 200));

      // 4. Verify a reminder notification was scheduled for the pact.
      expect(h.notifications.scheduledReminders, isNotEmpty);
      expect(h.notifications.scheduledReminders.first.pact.id, equals(_pactId));

      // 5. Verify the scheduled title/body match the Russian-localized reminder strings, not English.
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final reminder = h.notifications.scheduledReminders.first;
      expect(reminder.titleText, equals(ruL10n.notificationReminderTitle('Meditate')));
      expect(reminder.bodyText, equals(ruL10n.notificationReminderBody));
    });

    testWidgets(
        'reschedules_pending_reminders_after_in_app_language_switch: switching language via the in-app picker cancels and re-schedules already-pending reminders in the new language',
        (tester) async {
      // 1. Launch the app on English (system default), seed an active pact with a reminder offset, let the dashboard schedule its reminder (English text).
      final h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          deviceLocaleProvider.overrideWithValue(const Locale('en')),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedPact());
        },
      );
      addTearDown(h.dispose);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.pump(const Duration(milliseconds: 200));

      // 2. Verify the reminder notification is scheduled with English text.
      final enL10n = lookupAppLocalizations(const Locale('en'));
      expect(h.notifications.scheduledReminders, isNotEmpty);
      expect(h.notifications.scheduledReminders.first.titleText, equals(enL10n.notificationReminderTitle('Meditate')));

      // 3. Open the language picker and select Russian.
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-picker-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n(tester).languageRussian));
      await tester.pumpAndSettle();

      // 4. Verify h.notifications.cancelledPactIds now contains the pact ID (stale reminder was cancelled).
      expect(h.notifications.cancelledPactIds, contains(_pactId));

      // 5. Verify a fresh reminder notification was scheduled for the same showup with Russian text.
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      expect(h.notifications.scheduledReminders.last.titleText, equals(ruL10n.notificationReminderTitle('Meditate')));
    });

    testWidgets(
        'no_reschedule_when_selecting_same_language: selecting the already-active language is a no-op — no spurious cancel/re-schedule churn',
        (tester) async {
      // 1. Launch the app, seed an active pact with a reminder offset, let the dashboard schedule its reminder.
      final h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          deviceLocaleProvider.overrideWithValue(const Locale('en')),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedPact());
        },
      );
      addTearDown(h.dispose);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.pump(const Duration(milliseconds: 200));

      // Make Russian the active in-app override first, so re-selecting it below is
      // a genuine "already-active language" no-op (not a system→explicit change).
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-picker-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n(tester).languageRussian));
      await tester.pumpAndSettle();

      // 2. Record current counts of scheduledReminders and cancelledPactIds.
      final scheduledCountBefore = h.notifications.scheduledReminders.length;
      final cancelledCountBefore = h.notifications.cancelledPactIds.length;

      // 3. Open the language picker and re-select Russian (same as current).
      // Already-active option is prefixed with "✓ " on both platform pickers.
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-picker-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(l10n(tester).languageRussian));
      await tester.pumpAndSettle();

      // 4. Verify no additional cancellation or scheduling calls were made.
      expect(h.notifications.scheduledReminders.length, equals(scheduledCountBefore));
      expect(h.notifications.cancelledPactIds.length, equals(cancelledCountBefore));
    });
  });
}
