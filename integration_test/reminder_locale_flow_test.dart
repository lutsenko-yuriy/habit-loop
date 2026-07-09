// On-device entry point for the reminder-notification-locale flow test.
//
// Run with: flutter test integration_test/reminder_locale_flow_test.dart -d <device>
// Run on host: flutter test integration_test/reminder_locale_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Reminder locale flow', () {
    // TODO: restore late AppHarness h; tearDown(() => h.dispose());

    testWidgets(
        'schedules_reminder_in_device_locale_without_in_app_override: reminder notifications use the device/system locale when no in-app language override has ever been saved',
        (tester) async {
      // TODO: 1. Launch the app with the device/system locale set to Russian and no in-app locale preference ever saved.
      // TODO: 2. Seed an active pact with a reminder offset and no showups yet (dashboard's first-load sweep generates and schedules them).
      // TODO: 3. Load the dashboard.
      // TODO: 4. Verify a reminder notification was scheduled for the pact (h.notifications.scheduledReminders).
      // TODO: 5. Verify the scheduled title/body match the Russian-localized reminder strings (compared against lookupAppLocalizations(Locale('ru'))), not English.
    });

    testWidgets(
        'reschedules_pending_reminders_after_in_app_language_switch: switching language via the in-app picker cancels and re-schedules already-pending reminders in the new language',
        (tester) async {
      // TODO: 1. Launch the app on English (system default), seed an active pact with a reminder offset, let the dashboard schedule its reminder (English text).
      // TODO: 2. Verify the reminder notification is scheduled with English text.
      // TODO: 3. Open the language picker and select Russian.
      // TODO: 4. Verify h.notifications.cancelledPactIds now contains the pact ID (stale reminder was cancelled).
      // TODO: 5. Verify a fresh reminder notification was scheduled for the same showup with Russian text.
    });

    testWidgets(
        'no_reschedule_when_selecting_same_language: selecting the already-active language is a no-op — no spurious cancel/re-schedule churn',
        (tester) async {
      // TODO: 1. Launch the app, seed an active pact with a reminder offset, let the dashboard schedule its reminder in English.
      // TODO: 2. Record current counts of scheduledReminders and cancelledPactIds.
      // TODO: 3. Open the language picker and re-select English (same as current).
      // TODO: 4. Verify no additional cancellation or scheduling calls were made.
    });
  });
}
