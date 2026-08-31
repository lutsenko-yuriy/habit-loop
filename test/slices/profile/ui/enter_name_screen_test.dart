import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_screen.dart';

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
      home: EnterNameScreen(onDone: onDone),
    ),
  );
}

void main() {
  group('EnterNameScreen', () {
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

    testWidgets('caps a name that bypasses the field formatter (seeded straight into the controller)', (tester) async {
      // Simulates a >40-char name that arrived via sync — never typed through
      // the field's LengthLimitingTextInputFormatter — landing in the
      // controller via the initState seed instead.
      final userProfileRepository = InMemoryUserProfileRepository();
      final longName = 'A' * 60;

      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: userProfileRepository,
        seedDisplayName: longName,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName?.length, enterNameMaxLength);
    });

    testWidgets('caps by grapheme cluster, not UTF-16 code unit — a multi-code-point emoji stays intact',
        (tester) async {
      // '👨‍👩‍👧‍👦' (family emoji, ZWJ sequence) is one grapheme cluster but 7
      // UTF-16 code units — String.substring/String.runes truncation could
      // split it mid-sequence and store a mangled surrogate/ZWJ remnant.
      final userProfileRepository = InMemoryUserProfileRepository();
      const familyEmoji = '👨‍👩‍👧‍👦';
      final longName = familyEmoji * 41;

      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: userProfileRepository,
        seedDisplayName: longName,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('enter-name-save-button')));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, familyEmoji * enterNameMaxLength);
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

  group('EnterNameScreen on iOS (HAB-232 audit finding)', () {
    testWidgets('renders the Cupertino body and saves a trimmed name', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var doneCalled = false;
      final userProfileRepository = InMemoryUserProfileRepository();
      final onboardingService = FakeOnboardingPreferenceService();

      try {
        await tester.pumpWidget(_buildApp(
          onDone: () => doneCalled = true,
          onboardingService: onboardingService,
          userProfileRepository: userProfileRepository,
        ));
        await tester.pump();

        expect(find.byKey(const Key('enter-name-text-field')), findsOneWidget);
        final field = tester.widget(find.byKey(const Key('enter-name-text-field')));
        expect(field, isA<CupertinoTextField>());

        await tester.enterText(find.byKey(const Key('enter-name-text-field')), '  Alex  ');
        await tester.tap(find.byKey(const Key('enter-name-save-button')));
        await tester.pump();
        await tester.pump();

        expect(doneCalled, isTrue);
        expect(onboardingService.isNameEntryShown, isTrue);
        final saved = await userProfileRepository.getProfile();
        expect(saved?.displayName, 'Alex');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping skip marks name entry shown and calls onDone', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var doneCalled = false;
      final onboardingService = FakeOnboardingPreferenceService();

      try {
        await tester.pumpWidget(_buildApp(
          onDone: () => doneCalled = true,
          onboardingService: onboardingService,
          userProfileRepository: InMemoryUserProfileRepository(),
        ));
        await tester.pump();

        await tester.tap(find.byKey(const Key('enter-name-skip-button')));
        await tester.pump();
        await tester.pump();

        expect(doneCalled, isTrue);
        expect(onboardingService.isNameEntryShown, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('EnterNamePage layout (WU8 redesign)', () {
    testWidgets('Android: buttons are pushed to the bottom via an Expanded content area', (tester) async {
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
      ));
      await tester.pump();

      // The content column and the button column are siblings inside a
      // Column, with the content wrapped in Expanded so it fills the space
      // above the buttons instead of sitting immediately below the field.
      expect(find.byKey(const Key('enter-name-content-area')), findsOneWidget);
      final contentParent = tester.widget<Expanded>(
        find.ancestor(of: find.byKey(const Key('enter-name-content-area')), matching: find.byType(Expanded)).first,
      );
      expect(contentParent, isNotNull);
    });

    testWidgets('Android: title and body text are centered', (tester) async {
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
      ));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final title = tester.widget<Text>(find.text(l10n.enterNameTitle));
      final body = tester.widget<Text>(find.text(l10n.enterNameBody));
      expect(title.textAlign, TextAlign.center);
      expect(body.textAlign, TextAlign.center);
    });

    testWidgets('Android: buttons stretch to the same inset width as the rest of the page', (tester) async {
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
      ));
      await tester.pump();

      final saveButtonWidth = tester.getSize(find.byKey(const Key('enter-name-save-button'))).width;
      final fieldWidth = tester.getSize(find.byKey(const Key('enter-name-text-field'))).width;

      expect(saveButtonWidth, fieldWidth);
    });

    testWidgets('Android: text field uses an underline border, thicker when focused', (tester) async {
      await tester.pumpWidget(_buildApp(
        onDone: () {},
        onboardingService: FakeOnboardingPreferenceService(),
        userProfileRepository: InMemoryUserProfileRepository(),
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byKey(const Key('enter-name-text-field')));
      final decoration = field.decoration!;
      expect(decoration.border, isA<UnderlineInputBorder>());
      final unfocusedWidth = (decoration.enabledBorder as UnderlineInputBorder).borderSide.width;
      final focusedWidth = (decoration.focusedBorder as UnderlineInputBorder).borderSide.width;
      expect(focusedWidth, greaterThan(unfocusedWidth));
    });

    testWidgets('iOS: buttons are pushed to the bottom via an Expanded content area', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_buildApp(
          onDone: () {},
          onboardingService: FakeOnboardingPreferenceService(),
          userProfileRepository: InMemoryUserProfileRepository(),
        ));
        await tester.pump();

        expect(find.byKey(const Key('enter-name-content-area')), findsOneWidget);
        final contentParent = tester.widget<Expanded>(
          find.ancestor(of: find.byKey(const Key('enter-name-content-area')), matching: find.byType(Expanded)).first,
        );
        expect(contentParent, isNotNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS: buttons stretch to the same inset width as the rest of the page', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_buildApp(
          onDone: () {},
          onboardingService: FakeOnboardingPreferenceService(),
          userProfileRepository: InMemoryUserProfileRepository(),
        ));
        await tester.pump();

        final saveButtonWidth = tester.getSize(find.byKey(const Key('enter-name-save-button'))).width;
        final fieldWidth = tester.getSize(find.byKey(const Key('enter-name-text-field'))).width;

        expect(saveButtonWidth, fieldWidth);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS: text field shrinks its bottom border width on unfocus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_buildApp(
          onDone: () {},
          onboardingService: FakeOnboardingPreferenceService(),
          userProfileRepository: InMemoryUserProfileRepository(),
        ));
        await tester.pump();

        // The field autofocuses (same as before WU8) — starts focused/thick.
        final focused = tester.widget<CupertinoTextField>(find.byKey(const Key('enter-name-text-field')));
        final focusedWidth = ((focused.decoration as BoxDecoration).border as Border).bottom.width;

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        final unfocused = tester.widget<CupertinoTextField>(find.byKey(const Key('enter-name-text-field')));
        final unfocusedWidth = ((unfocused.decoration as BoxDecoration).border as Border).bottom.width;
        expect(focusedWidth, greaterThan(unfocusedWidth));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
