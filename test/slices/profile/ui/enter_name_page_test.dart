import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_page.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/onboarding/fake_onboarding_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

Widget _buildApp({
  required VoidCallback onDone,
  required FakeOnboardingPreferenceService onboardingService,
  required InMemoryUserProfileRepository userProfileRepository,
  FakeAnalyticsService? analyticsService,
  String? seedDisplayName,
}) {
  return ProviderScope(
    overrides: [
      onboardingPreferenceServiceProvider.overrideWithValue(onboardingService),
      userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      syncServiceProvider.overrideWithValue(FakeSyncService()),
      remoteConfigServiceProvider.overrideWithValue(FakeRemoteConfigService()),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (seedDisplayName != null)
        displayNameProvider.overrideWith(() => DisplayNameNotifier(seedDisplayName: seedDisplayName)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: EnterNamePage(onDone: onDone),
    ),
  );
}

void main() {
  group('EnterNamePage', () {
    testWidgets('shows the title, hint and text field', (tester) async {
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
      ));
      await tester.pump();

      expect(find.byKey(const Key('enter-name-text-field')), findsOneWidget);
      expect(find.byKey(const Key('enter-name-save-button')), findsOneWidget);
      expect(find.byKey(const Key('enter-name-skip-button')), findsOneWidget);
    });

    testWidgets('saving a trimmed name persists it and calls onDone', (tester) async {
      var doneCalled = false;
      final userProfileRepository = InMemoryUserProfileRepository();
      final onboardingService = FakeOnboardingPreferenceService();

      await tester.pumpWidget(_buildApp(
        onDone: () => doneCalled = true,
        onboardingService: onboardingService,
        userProfileRepository: userProfileRepository,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('enter-name-text-field')), '  Alex  ');
      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      expect(doneCalled, isTrue);
      expect(onboardingService.isNameEntryShown, isTrue);
      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Alex');
    });

    testWidgets('caps a name longer than the max length', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      final longName = 'A' * 60;

      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: userProfileRepository,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('enter-name-text-field')), longName);
      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName?.length, enterNameMaxLength);
    });

    testWidgets('tapping skip marks name entry shown, saves nothing, and calls onDone', (tester) async {
      var doneCalled = false;
      final userProfileRepository = InMemoryUserProfileRepository();
      final onboardingService = FakeOnboardingPreferenceService();

      await tester.pumpWidget(_buildApp(
        onDone: () => doneCalled = true,
        onboardingService: onboardingService,
        userProfileRepository: userProfileRepository,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('enter-name-skip-button')));
      await tester.pump();
      await tester.pump();

      expect(doneCalled, isTrue);
      expect(onboardingService.isNameEntryShown, isTrue);
      expect(await userProfileRepository.getProfile(), isNull);
    });

    testWidgets('submitting empty/whitespace-only text is treated as a skip', (tester) async {
      var doneCalled = false;
      final userProfileRepository = InMemoryUserProfileRepository();
      final onboardingService = FakeOnboardingPreferenceService();

      await tester.pumpWidget(_buildApp(
        onDone: () => doneCalled = true,
        onboardingService: onboardingService,
        userProfileRepository: userProfileRepository,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('enter-name-text-field')), '   ');
      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      expect(doneCalled, isTrue);
      expect(onboardingService.isNameEntryShown, isTrue);
      expect(await userProfileRepository.getProfile(), isNull);
    });

    testWidgets('pre-fills the text field with an existing local name', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Sam', updatedAt: DateTime(2026)));
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: userProfileRepository,
        seedDisplayName: 'Sam',
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byKey(const Key('enter-name-text-field')));
      expect(field.controller?.text, 'Sam');
    });

    testWidgets('fires the display_name_entry_completed event with action=saved', (tester) async {
      final analyticsService = FakeAnalyticsService();

      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
        analyticsService: analyticsService,
      ));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('enter-name-text-field')), 'Alex');
      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      final events = analyticsService.loggedEvents;
      expect(
          events.any((e) => e.name == 'display_name_entry_completed' && e.toParameters()['action'] == 'saved'), isTrue);
    });
  });
}
