// Integration tests for personalizing notifications and greetings with the
// user's first name (HAB-232).
//
// Run on host:   flutter test integration_test/display_name_flow_test.dart
// Run on device: flutter test integration_test/display_name_flow_test.dart -d <device>
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/onboarding/fake_onboarding_preference_service.dart';
import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

final _flagOn = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': true}),
);
final _flagOff = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': false}),
);

// Fixed clock, mirroring reminder_locale_flow_test.dart's _seedPact pattern —
// showups are generated for "today" through +10 days, independent of the
// real wall-clock time the test runs at. _seedGreetingPact's startDate was
// originally a literal 2026-01-01 with no todayProvider override — as real
// time passed since WU6 was authored, the dashboard's gap-fill sweep had to
// backfill a growing number of days on every run, until it became
// prohibitively slow on-device (HAB-232 WU7 fix, root-caused via a pre-WU7
// baseline comparison run of the identical scenario).
final _testNow = DateTime(2099, 6, 15, 7, 0);
final _testToday = DateTime(2099, 6, 15);

Pact _seedGreetingPact() => buildPact(
      id: 'greeting-flow-test-pact-1',
      habitName: 'Meditate',
      startDate: _testToday,
    );

Pact _seedReminderPact() => buildPact(
      id: 'reminder-name-flow-test-pact-1',
      habitName: 'Meditate',
      startDate: _testToday,
      reminderOffset: const Duration(minutes: 30),
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
        'updates the stored name on save, and reflects the new value on reopen — no app restart', (tester) async {
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

      // WU9: title is personalized ("Hi Alex") whenever the flag is on and a
      // name is on file — dashboardTitle ("Dashboard") never renders here.
      await waitFor(tester, find.text(l10n(tester).dashboardGreetingPersonalized('Alex')));

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

    // Split into one harness per test (rather than several AppHarness.create
    // calls inside a single testWidgets, as the earlier scenarios in this
    // file do) — reusing the root ProviderScope element across multiple
    // dispose()+recreate() cycles within one test body was observed to leak
    // stream-backed provider state (authStateChangesProvider, in particular)
    // across "launches" when anonymity/pact-count actually change between
    // them, unlike the existing skip/relaunch scenario above which keeps
    // both constant. One harness per test sidesteps that entirely.
    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: dashboard greeting is personalized when a name is on file and the flag is on',
        (tester) async {
      final repo = InMemoryUserProfileRepository();
      await repo.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        // Fixed clock (HAB-232 WU7 fix) — without it, "today" is the real
        // wall-clock date, which drifts further from _seedGreetingPact's
        // fixed startDate every day this suite runs, making the dashboard's
        // gap-fill sweep backfill more and more showups until the on-device
        // run becomes prohibitively slow (root-caused via a pre-WU7 baseline
        // comparison — same stall, unrelated to WU7's own changes).
        extraOverrides: [_flagOn, todayProvider.overrideWithValue(_testNow)],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: repo,
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedGreetingPact());
        },
      );
      await waitFor(tester, find.text(l10n(tester).dashboardGreetingPersonalized('Alex')));
      expect(find.text(l10n(tester).dashboardTitle), findsNothing);
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: dashboard title stays plain when no name is on file',
        (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn, todayProvider.overrideWithValue(_testNow)],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: InMemoryUserProfileRepository(),
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedGreetingPact());
        },
      );
      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: dashboard title stays plain when the flag is off despite a name on file',
        (tester) async {
      final repo = InMemoryUserProfileRepository();
      await repo.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOff, todayProvider.overrideWithValue(_testNow)],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: repo,
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedGreetingPact());
        },
      );
      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      expect(find.text(l10n(tester).dashboardGreetingPersonalized('Alex')), findsNothing);
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: onboarding slide 0 is personalized when a name is on file and the flag is on',
        (tester) async {
      final repo = InMemoryUserProfileRepository();
      await repo.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: repo,
      );
      await waitFor(tester, find.text(l10n(tester).onboardingSlide0TitlePersonalized('Alex')));
      expect(find.text(l10n(tester).onboardingSlide0Title), findsNothing);
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: onboarding slide 0 falls back to neutral copy when no name is on file',
        (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn],
        initiallyAnonymous: true,
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: InMemoryUserProfileRepository(),
      );
      await waitFor(tester, find.text(l10n(tester).onboardingSlide0Title));
    });

    testWidgets(
        'personalization_shown_only_when_name_on_file_and_flag_on: onboarding slide 0 shows neutral copy when the flag is off despite a name on file',
        (tester) async {
      final repo = InMemoryUserProfileRepository();
      await repo.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOff],
        initiallyAnonymous: true,
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: repo,
      );
      await waitFor(tester, find.text(l10n(tester).onboardingSlide0Title));
    });

    testWidgets(
        'reminder_notification_text_contains_name_when_on_file: a scheduled reminder notification\'s text contains the user\'s name when one is on file',
        (tester) async {
      // 1. Launch harness with the flag on, a name on file, an active pact
      //    with a reminder offset, and a fixed clock.
      final repo = InMemoryUserProfileRepository();
      await repo.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn, todayProvider.overrideWithValue(_testNow)],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: repo,
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedReminderPact());
        },
      );

      // 2. Let the dashboard's first-load sweep schedule the reminder.
      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.pump(const Duration(milliseconds: 200));

      // 3/4. The scheduled reminder's title contains the seeded name.
      expect(h.notifications.scheduledReminders, isNotEmpty);
      final named = h.notifications.scheduledReminders.first;
      expect(named.pact.id, equals(_seedReminderPact().id));
      expect(named.titleText, equals(l10n(tester).notificationReminderTitlePersonalized('Alex', 'Meditate')));
    });

    testWidgets(
        'reminder_notification_text_contains_name_when_on_file: falls back to neutral copy when no name is on file',
        (tester) async {
      // 5. (Contrast) same setup with no name on file — neutral copy, no name.
      h = await AppHarness.create(
        tester,
        extraOverrides: [_flagOn, todayProvider.overrideWithValue(_testNow)],
        onboardingService: FakeOnboardingPreferenceService(initialNameEntryShown: true),
        userProfileRepository: InMemoryUserProfileRepository(),
        beforePump: (h) async {
          await h.pactRepo.savePact(_seedReminderPact());
        },
      );

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.pump(const Duration(milliseconds: 200));

      expect(h.notifications.scheduledReminders, isNotEmpty);
      final neutral = h.notifications.scheduledReminders.first;
      expect(neutral.titleText, equals(l10n(tester).notificationReminderTitle('Meditate')));
    });
  });
}
