// Integration tests for personalizing notifications and greetings with the
// user's first name (HAB-232).
//
// Run on host:   flutter test integration_test/display_name_flow_test.dart
// Run on device: flutter test integration_test/display_name_flow_test.dart -d <device>
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/onboarding/fake_onboarding_preference_service.dart';
import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

final _flagOn = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': true}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Display name personalization flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'enter_name_page_shown_on_fresh_install_and_saves_name: fresh install shows EnterNameScreen and saving a name persists it',
        (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: userProfileRepository,
      );

      expect(find.byKey(const Key('enter-name-text-field')), findsOneWidget);

      await saveEnterName(tester, 'Alex');

      expect(find.byKey(const Key('enter-name-text-field')), findsNothing);
      expect(find.text(l10n(tester).createPact), findsOneWidget);

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Alex');
    });

    testWidgets(
        'enter_name_page_skip_is_permanent: skipping EnterNameScreen marks it shown so it is never re-prompted on a later launch',
        (tester) async {
      final onboardingService = FakeOnboardingPreferenceService();
      final userProfileRepository = InMemoryUserProfileRepository();

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        onboardingService: onboardingService,
        userProfileRepository: userProfileRepository,
      );

      expect(find.byKey(const Key('enter-name-text-field')), findsOneWidget);

      await skipEnterName(tester);

      expect(find.byKey(const Key('enter-name-text-field')), findsNothing);
      expect(onboardingService.isNameEntryShown, isTrue);

      h.dispose();

      // Simulate a subsequent launch: same onboarding-service/profile-repository
      // instances, fresh AppHarness (not a truly fresh install).
      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        onboardingService: onboardingService,
        userProfileRepository: userProfileRepository,
      );

      expect(find.byKey(const Key('enter-name-text-field')), findsNothing);
    });

    testWidgets(
        'enter_name_page_prefills_existing_local_name: an existing local name pre-fills EnterNameScreen instead of showing it empty',
        (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Sam', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        userProfileRepository: userProfileRepository,
      );

      expect(find.byKey(const Key('enter-name-text-field')), findsOneWidget);
      expect(enterNameFieldText(tester), 'Sam');
    });

    testWidgets(
        'change_name_dialog_updates_stored_name: the ⋯ menu\'s "Change name" dialog pre-fills the current name, '
        'updates the stored name on save, and reflects the new value on reopen — no app restart '
        '(WU6 has not shipped yet, so the dashboard greeting header does not exist; asserted here via the '
        "dialog's own pre-fill instead)", (tester) async {
      // 1. Launch harness with flag on and a name already on file. Not
      //    initiallyAnonymous (default false), so the dashboard loads
      //    directly with no pact needed to skip the onboarding carousel.
      //    isNameEntryShown must be seeded true, or EnterNameScreen (WU4)
      //    would intercept the dashboard first (this is a returning user
      //    with a name already on file, not a fresh install).
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: userProfileRepository,
      );

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));

      // 2/3. Open the kebab menu, tap "Change name".
      await openChangeNameDialogFromKebab(tester);

      // 4. ChangeNameDialog is shown, pre-filled with the current name.
      expect(find.byKey(const Key('change-name-text-field')), findsOneWidget);
      expect(changeNameFieldText(tester), 'Alex');

      // 5/6. Clear the field, enter a new name, confirm — dialog dismisses.
      await saveChangeName(tester, 'Sam');
      expect(find.byKey(const Key('change-name-text-field')), findsNothing);

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Sam');

      // 7. Re-open the dialog with no app restart/harness recreation — the
      //    new name is reflected immediately via displayNameProvider.
      await openChangeNameDialogFromKebab(tester);
      expect(changeNameFieldText(tester), 'Sam');
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
