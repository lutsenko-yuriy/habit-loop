// Integration tests for personalizing notifications and greetings with the
// user's first name (HAB-232).
//
// Run on host:   flutter test integration_test/display_name_flow_test.dart
// Run on device: flutter test integration_test/display_name_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Display name personalization flow', () {
    // TODO: once driver code is filled in, declare `late AppHarness h;` and
    // `tearDown(() => h.dispose());` here, mirroring other flow test files.

    testWidgets(
        'enter_name_page_shown_on_fresh_install_and_saves_name: fresh install shows EnterNamePage and saving a name persists it',
        (tester) async {
      // TODO: 1. Launch harness with flag `display_name_personalization_enabled: true`, `initiallyAnonymous: true`, no pacts seeded.
      // TODO: 2. Verify EnterNamePage is shown (its title/key) instead of the onboarding carousel/dashboard.
      // TODO: 3. Enter a name into the text field.
      // TODO: 4. Tap save.
      // TODO: 5. Verify EnterNamePage is dismissed and the app proceeds to its normal first-launch flow.
      // TODO: 6. Verify the saved name is now readable from the underlying preference store used by displayNameProvider.
    });

    testWidgets(
        'enter_name_page_skip_is_permanent: skipping EnterNamePage marks it shown so it is never re-prompted on a later launch',
        (tester) async {
      // TODO: 1. Launch harness with flag on, fresh install (no pacts, isNameEntryShown false).
      // TODO: 2. Verify EnterNamePage is shown.
      // TODO: 3. Tap "Skip".
      // TODO: 4. Verify EnterNamePage is dismissed.
      // TODO: 5. Dispose harness, recreate a new AppHarness reusing the same underlying preference store/state (not a truly fresh install) to simulate a subsequent launch.
      // TODO: 6. Verify EnterNamePage is NOT shown on this second launch (dashboard/carousel appears directly instead).
    });

    testWidgets(
        'enter_name_page_prefills_existing_local_name: an existing local name pre-fills EnterNamePage instead of showing it empty',
        (tester) async {
      // TODO: 1. Launch harness with flag on, beforePump seeding an existing local display name into the preference store (simulating leftover local state from before reinstall), with isNameEntryShown false and no pacts.
      // TODO: 2. Verify EnterNamePage is shown.
      // TODO: 3. Verify its text field is pre-populated with the seeded name.
    });

    testWidgets(
        'change_name_dialog_updates_dashboard_greeting_without_restart: the ⋯ menu\'s "Change name" dialog updates the stored name and the dashboard greeting updates without a restart',
        (tester) async {
      // TODO: 1. Launch harness with flag on, a name already on file, at least one pact seeded so the dashboard loads directly.
      // TODO: 2. Verify the dashboard greeting shows the original name.
      // TODO: 3. Open the kebab menu, tap "Change name".
      // TODO: 4. Verify ChangeNameDialog is shown, pre-filled with the current name.
      // TODO: 5. Clear the field and enter a new name, confirm.
      // TODO: 6. Verify the dialog is dismissed.
      // TODO: 7. Verify the dashboard greeting now shows the new name, with no app restart/harness recreation.
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: onboarding slide 0 and the dashboard greeting personalize only when a name is on file and the flag is on',
        (tester) async {
      // TODO: 1. Case A (personalized): flag on, name on file, at least one pact seeded — verify dashboard greeting contains the name.
      // TODO: 2. Case A onboarding: flag on, name on file, zero pacts (so onboarding carousel/slide 0 renders) — verify slide 0's copy contains the name.
      // TODO: 3. Case B (no name): flag on, no name on file — verify dashboard greeting and onboarding slide 0 show neutral/current (non-personalized) copy.
      // TODO: 4. Case C (flag off): flag off, name on file — verify dashboard greeting and onboarding slide 0 show neutral/current copy despite a name being present.
    });

    testWidgets(
        'reminder_notification_text_contains_name_when_on_file: a scheduled reminder notification\'s text contains the user\'s name when one is on file',
        (tester) async {
      // TODO: 1. Launch harness with flag on, a name on file, seed an active pact with a reminder offset (mirroring reminder_locale_flow_test.dart's _seedPact pattern), fixed todayProvider.
      // TODO: 2. Let the dashboard's first-load sweep schedule the reminder.
      // TODO: 3. Verify h.notifications.scheduledReminders is non-empty.
      // TODO: 4. Verify the scheduled reminder's titleText/bodyText contains the seeded name (built via NotificationTextBuilder with the name resolved).
      // TODO: 5. (Contrast) repeat with no name on file — verify the reminder text does not contain a name and matches the current neutral copy.
    });
  });
}
