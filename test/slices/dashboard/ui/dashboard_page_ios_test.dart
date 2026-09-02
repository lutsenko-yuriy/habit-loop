import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildTestApp({
  bool hasPacts = true,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  FakeRemoteConfigService? remoteConfig,
  Locale? localeOverride,
  Locale locale = const Locale('en'),
  DashboardState state = const DashboardState(isLoading: false),
  InMemoryUserProfileRepository? userProfileRepository,
  String? seedDisplayName,
}) {
  return ProviderScope(
    overrides: [
      pactListViewModelProvider.overrideWith(_LoadedPactListViewModel.new),
      analyticsServiceProvider.overrideWithValue(analyticsService ?? FakeAnalyticsService()),
      // HAB-157: language switch triggers a reminder reschedule pass that reads these.
      pactRepositoryProvider.overrideWithValue(InMemoryPactRepository()),
      showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
      if (localeService != null) localePreferenceServiceProvider.overrideWithValue(localeService),
      if (remoteConfig != null) remoteConfigServiceProvider.overrideWithValue(remoteConfig),
      if (localeOverride != null) localeOverrideProvider.overrideWith((ref) => localeOverride),
      if (userProfileRepository != null) userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      // HAB-232: displayNameProvider is only seeded from the repository by
      // AppContainer's real bootstrap — this bare ProviderScope needs the
      // same seed applied explicitly (mirrors enter_name_screen_test.dart).
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
      locale: locale,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: DashboardPageIos(
          state: state,
          hasPacts: hasPacts,
          showCarousel: !hasPacts,
          onDaySelected: (_) {},
          onCreatePact: () async {},
          onShowupTapped: (_) async {},
          onAbout: () async {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('iOS dashboard nav bar has explicit surface backgroundColor to prevent white-on-drag', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final navBar = tester.widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    final theme = Theme.of(tester.element(find.byType(DashboardPageIos)));

    expect(navBar.backgroundColor, theme.colorScheme.surface);
  });

  testWidgets('iOS dashboard uses scaffold color without custom home indicator affordances', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final safeArea = tester.widget<SafeArea>(
      find.byKey(const Key('dashboard-ios-safe-area')),
    );
    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    final theme = Theme.of(tester.element(find.byType(DashboardPageIos)));

    expect(scaffold.backgroundColor, theme.colorScheme.surface);
    expect(safeArea.bottom, isFalse);
    expect(find.byKey(const Key('dashboard-ios-bottom-panel-safe-area-fill')), findsNothing);
    expect(find.byKey(const Key('dashboard-ios-bottom-panel-safe-area-ignore-pointer')), findsNothing);
    expect(find.byKey(const Key('dashboard-ios-home-gesture-reserve')), findsNothing);
  });

  testWidgets('iOS dashboard shows kebab menu button when multiple actions are enabled', (tester) async {
    // Default config: About + Language + Debug (debug build) → 3 candidates → kebab shown.
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('kebab-menu-button')), findsOneWidget);
    // Language is inside the kebab, not a standalone nav-bar button.
    expect(find.byKey(const Key('language-picker-button')), findsNothing);
  });

  testWidgets('iOS dashboard nav bar buttons expose Semantics labels for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_buildTestApp());

    expect(
      tester.getSemantics(find.byKey(const Key('sync-status-button'))),
      matchesSemantics(label: 'Sync status', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('kebab-menu-button'))),
      matchesSemantics(label: 'More options', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('create-pact-button'))),
      matchesSemantics(label: 'Create a Pact', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('iOS standalone debug button keeps its Semantics label when promoted out of the kebab', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {
        'about_screen_enabled': false,
        'language_selection_enabled': false,
        'display_name_personalization_enabled': false,
      }),
    ));

    expect(
      tester.getSemantics(find.byKey(const Key('remote-config-debug-button'))),
      matchesSemantics(label: 'Debug', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('iOS dashboard hides sync button when network_sync_enabled is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'network_sync_enabled': false}),
    ));

    expect(find.byKey(const Key('sync-status-button')), findsNothing);
  });

  testWidgets('iOS dashboard hides language item from kebab when language_selection_enabled is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'language_selection_enabled': false}),
    ));

    // 2 candidates remain (Debug + About) → kebab still shown, language key absent.
    expect(find.byKey(const Key('kebab-menu-button')), findsOneWidget);
    expect(find.byKey(const Key('language-picker-button')), findsNothing);
  });

  testWidgets('iOS dashboard shows onboarding carousel when hasPacts is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      hasPacts: false,
      remoteConfig: FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
    ));

    // Carousel replaces the regular scaffold — no kebab button.
    expect(find.byKey(const Key('kebab-menu-button')), findsNothing);
    expect(find.text('Create a Pact'), findsOneWidget);
  });

  testWidgets('iOS dashboard single-item shortcut shows standalone button with no kebab', (tester) async {
    // Disable About + Language → only Debug (always in debug build) is a candidate → shortcut.
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {
        'about_screen_enabled': false,
        'language_selection_enabled': false,
        'display_name_personalization_enabled': false,
      }),
    ));

    expect(find.byKey(const Key('kebab-menu-button')), findsNothing);
    expect(find.byKey(const Key('remote-config-debug-button')), findsOneWidget);
  });

  testWidgets('tapping kebab button opens CupertinoActionSheet with all enabled items', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('en')));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('tapping kebab button fires KebabMenuOpenedEvent analytics', (tester) async {
    final analytics = FakeAnalyticsService();
    await tester.pumpWidget(_buildTestApp(analyticsService: analytics));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();

    expect(analytics.loggedEvents.any((e) => e.name == 'kebab_menu_opened'), isTrue);
  });

  testWidgets('tapping Language in kebab shows CupertinoActionSheet with language options', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('en')));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    expect(find.text('✓ English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    expect(find.text('Use system language'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('action sheet shows checkmark on currently selected language', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('fr')));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    expect(find.text('✓ French'), findsOneWidget);
    expect(find.text('✓ English'), findsNothing);
  });

  testWidgets('action sheet shows checkmark on system option when localeOverride is null', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    expect(find.text('✓ Use system language'), findsOneWidget);
  });

  testWidgets('selecting a language from action sheet fires analytics and updates locale provider', (tester) async {
    final analyticsService = FakeAnalyticsService();
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(_buildTestApp(
      analyticsService: analyticsService,
      localeService: localeService,
      localeOverride: const Locale('en'),
    ));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_change_requested'), isTrue);
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);

    final changedEvent = analyticsService.loggedEvents.firstWhere((e) => e.name == 'language_changed');
    expect(changedEvent.toParameters()['to_language'], 'fr');
    expect(localeService.savedLocale, const Locale('fr'));
  });

  testWidgets('selecting system language clears locale override', (tester) async {
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(_buildTestApp(localeService: localeService, localeOverride: const Locale('fr')));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use system language'));
    await tester.pumpAndSettle();

    expect(localeService.clearLocaleCallCount, greaterThan(0));
  });

  testWidgets('re-selecting the already-selected language does not fire analytics or save', (tester) async {
    final analyticsService = FakeAnalyticsService();
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(_buildTestApp(
      analyticsService: analyticsService,
      localeService: localeService,
      localeOverride: const Locale('en'),
    ));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✓ English'));
    await tester.pumpAndSettle();

    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    expect(localeService.savedLocale, isNull);
  });

  testWidgets('selecting system language when already on system is a no-op', (tester) async {
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(_buildTestApp(localeService: localeService));

    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✓ Use system language'));
    await tester.pumpAndSettle();

    expect(localeService.clearLocaleCallCount, 0);
  });

  testWidgets('tapping language button in carousel (hasPacts=false) shows CupertinoActionSheet', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      hasPacts: false,
      remoteConfig: FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
      localeOverride: const Locale('en'),
    ));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('✓ English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('showup tile subtitle uses locale-specific duration label', (tester) async {
    final showup = Showup(
      id: 's1',
      pactId: 'pact-1',
      scheduledAt: DateTime(2026, 3, 29, 7, 0),
      duration: const Duration(minutes: 120),
      status: ShowupStatus.pending,
    );
    final state = DashboardState(
      isLoading: false,
      selectedDayIndex: 0,
      todayIndex: 0,
      calendarDays: [
        CalendarDayEntry(date: DateTime(2026, 3, 29), showups: [showup])
      ],
      pactNames: const {'pact-1': 'Meditate'},
    );

    await tester.pumpWidget(_buildTestApp(locale: const Locale('ru'), state: state));
    await tester.pumpAndSettle();

    expect(find.textContaining('120 мин'), findsOneWidget);
    expect(find.textContaining('120 min'), findsNothing);
  });

  group('Change name (HAB-232 WU5)', () {
    final flagOn = FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': true});
    final flagOff = FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': false});

    testWidgets('change-name item hidden from kebab when flag is off', (tester) async {
      await tester.pumpWidget(_buildTestApp(remoteConfig: flagOff));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('change-name-button')), findsNothing);
    });

    testWidgets('change-name item shown in kebab and opens dialog pre-filled with the current name', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('change-name-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<CupertinoTextField>(find.byKey(const Key('change-name-text-field')));
      expect(field.controller?.text, 'Alex');
    });

    testWidgets('saving a new name persists it and fires display_name_changed', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), 'Sam');
      await tester.pump(); // rebuild so the (now non-empty) field re-enables Save
      await tester.tap(find.byKey(const Key('change-name-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('change-name-text-field')), findsNothing);

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Sam');

      final changedEvent = analyticsService.loggedEvents.firstWhere((e) => e.name == 'display_name_changed');
      expect(changedEvent.toParameters()['name_length'], 3);
      expect(changedEvent.toParameters()['had_previous_name'], isTrue);
    });

    testWidgets('saving with no prior name fires display_name_changed with had_previous_name=false', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
      ));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), 'Sam');
      await tester.pump(); // rebuild so the (now non-empty) field re-enables Save
      await tester.tap(find.byKey(const Key('change-name-save-button')));
      await tester.pumpAndSettle();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Sam');

      final changedEvent = analyticsService.loggedEvents.firstWhere((e) => e.name == 'display_name_changed');
      expect(changedEvent.toParameters()['had_previous_name'], isFalse);
    });

    testWidgets('save button stays enabled when the field is cleared, and clearing it removes the name (HAB-232)',
        (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), '   ');
      await tester.pump();

      final saveButton = tester.widget<CupertinoDialogAction>(find.byKey(const Key('change-name-save-button')));
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('change-name-save-button')));
      await tester.pumpAndSettle();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, isNull);
    });

    testWidgets('cancel dismisses the dialog without saving', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), 'Sam');
      await tester.tap(find.byKey(const Key('change-name-cancel-button')));
      await tester.pumpAndSettle();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Alex');
    });
  });

  group('nav bar title greeting (HAB-232 WU9)', () {
    testWidgets('title is personalized when a name is on file and the flag is on', (tester) async {
      final flagOn = FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': true});
      await tester.pumpWidget(_buildTestApp(remoteConfig: flagOn, seedDisplayName: 'Alex'));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(DashboardPageIos)))!;
      expect(find.text(l10n.dashboardGreetingPersonalized('Alex')), findsOneWidget);
      expect(find.text(l10n.dashboardTitle), findsNothing);
    });

    testWidgets('title stays plain "Dashboard" when no name is on file', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(DashboardPageIos)))!;
      expect(find.text(l10n.dashboardTitle), findsOneWidget);
    });

    testWidgets('title stays plain "Dashboard" when a name is on file but the flag is off', (tester) async {
      final flagOff = FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': false});
      await tester.pumpWidget(_buildTestApp(remoteConfig: flagOff, seedDisplayName: 'Alex'));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(DashboardPageIos)))!;
      expect(find.text(l10n.dashboardTitle), findsOneWidget);
      expect(find.text(l10n.dashboardGreetingPersonalized('Alex')), findsNothing);
    });
  });

  group('Todo list tile icon by UI state (HAB-263)', () {
    DashboardState stateWithShowup(
      Showup showup, {
      Map<String, Duration?> reminderOffsetByPactId = const {},
      Map<String, List<PactBreak>> breaksByPactId = const {},
    }) =>
        DashboardState(
          isLoading: false,
          selectedDayIndex: 0,
          todayIndex: 0,
          calendarDays: [
            CalendarDayEntry(date: DateTime(2026, 3, 29), showups: [showup]),
          ],
          pactNames: const {'pact-1': 'Meditate'},
          reminderOffsetByPactId: reminderOffsetByPactId,
          breaksByPactId: breaksByPactId,
        );

    Color colorFor(WidgetTester tester, Color Function(ShowupStatusColors) pick) {
      final context = tester.element(find.byType(DashboardPageIos));
      return pick(ShowupStatusColors.cupertino(context));
    }

    testWidgets('planned showup (no reminder fired yet) shows outline circle in pending color', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

      await tester.pumpWidget(_buildTestApp(state: stateWithShowup(showup)));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.circle), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.circle));
      expect(icon.color, colorFor(tester, (c) => c.pending));
      expect(find.textContaining('Planned'), findsOneWidget);
    });

    testWidgets('waitingForStart showup (reminder fired, not yet started) shows filled amber circle', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final state = stateWithShowup(
        showup,
        reminderOffsetByPactId: {'pact-1': const Duration(minutes: 30)},
      );

      await tester.pumpWidget(_buildTestApp(state: state));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.clock_fill));
      expect(icon.color, colorFor(tester, (c) => c.waitingForStart));
      // Subtitle now tracks uiState, not the raw "Pending" domain status (HAB-263 audit finding).
      expect(find.textContaining('Waiting for start'), findsOneWidget);
      expect(find.textContaining('Pending'), findsNothing);
    });

    testWidgets('active (in-progress) showup shows filled amber circle', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: const Duration(minutes: 30),
        status: ShowupStatus.pending,
      );

      await tester.pumpWidget(_buildTestApp(state: stateWithShowup(showup)));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.clock_fill));
      expect(icon.color, colorFor(tester, (c) => c.waitingForStart));
    });

    testWidgets('done showup keeps its own filled check icon, unaffected', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );

      await tester.pumpWidget(_buildTestApp(state: stateWithShowup(showup)));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.check_mark_circled_solid), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.clock_fill), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.check_mark_circled_solid));
      expect(icon.color, colorFor(tester, (c) => c.done));
    });

    testWidgets('failed showup keeps its own xmark icon, unaffected', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.failed,
      );

      await tester.pumpWidget(_buildTestApp(state: stateWithShowup(showup)));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.clock_fill), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.xmark_circle_fill));
      expect(icon.color, colorFor(tester, (c) => c.failed));
    });

    testWidgets('on-break showup keeps its own pause icon in blue, unaffected', (tester) async {
      final showup = Showup(
        id: 's1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 12),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final state = stateWithShowup(
        showup,
        breaksByPactId: {
          'pact-1': [
            PactBreak(id: 'b1', pactId: 'pact-1', startDate: DateTime(2026, 1, 1), rationale: 'rest'),
          ],
        },
      );

      await tester.pumpWidget(_buildTestApp(state: state));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.pause_circle_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.clock_fill), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.pause_circle_fill));
      expect(icon.color, colorFor(tester, (c) => c.onBreak));
    });
  });
}

class _LoadedPactListViewModel extends PactListViewModel {
  @override
  PactListState build() => PactListState(entries: [
        PactListEntry(
          pact: Pact(
            id: 'pact-1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ),
      ]);
}
