import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/kebab_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_actions.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildTestApp({
  bool hasPacts = true,
  bool? showCarousel,
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
      home: DashboardPageAndroid(
        state: state,
        hasPacts: hasPacts,
        showCarousel: showCarousel ?? !hasPacts,
        onDaySelected: (_) {},
        onCreatePact: () async {},
        onShowupTapped: (_) async {},
        onAbout: () async {},
      ),
    ),
  );
}

Future<void> _openKebab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('kebab-menu-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android dashboard shows kebab menu button when multiple actions are enabled', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('kebab-menu-button')), findsOneWidget);
    // language picker is inside the kebab, not directly in the app bar
    expect(find.byIcon(Icons.language), findsNothing);
  });

  testWidgets('Android dashboard app bar buttons expose accessible tooltips', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final syncButton = tester.widget<IconButton>(find.byKey(const Key('sync-status-button')));
    expect(syncButton.tooltip, 'Sync status');

    final kebabButton = tester.widget<PopupMenuButton<DashboardActionType>>(find.byKey(const Key('kebab-menu-button')));
    expect(kebabButton.tooltip, 'More options');

    final fab = tester.widget<FloatingActionButton>(find.byKey(const Key('create-pact-button')));
    expect(fab.tooltip, 'Create a Pact');
  });

  testWidgets('Android standalone debug button keeps its tooltip when promoted out of the kebab', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {
        'language_selection_enabled': false,
        'about_screen_enabled': false,
      }),
    ));

    final debugButton = tester.widget<IconButton>(find.byKey(const Key('remote-config-debug-button')));
    expect(debugButton.tooltip, 'Debug');
  });

  testWidgets('Android dashboard hides sync button when network_sync_enabled is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'network_sync_enabled': false}),
    ));

    expect(find.byKey(const Key('sync-status-button')), findsNothing);
  });

  testWidgets('Android dashboard hides language item from kebab when language_selection_enabled is false',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'language_selection_enabled': false}),
    ));

    await _openKebab(tester);

    expect(find.byKey(const Key('language-picker-button')), findsNothing);
  });

  testWidgets('Android dashboard shows onboarding carousel when hasPacts is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      hasPacts: false,
      remoteConfig: FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
    ));

    // Carousel replaces the regular scaffold — no app bar or kebab button.
    expect(find.byKey(const Key('kebab-menu-button')), findsNothing);
    expect(find.text('Create a Pact'), findsOneWidget);
  });

  testWidgets('Android dashboard no-pacts CTA is a FilledButton (not ElevatedButton)', (tester) async {
    // hasPacts=false with showCarousel explicitly false exercises the signed-in,
    // zero-pacts empty state (as opposed to the anonymous-user carousel).
    await tester.pumpWidget(_buildTestApp(hasPacts: false, showCarousel: false));
    await tester.pumpAndSettle();

    final ctaFinder = find.byKey(const Key('create-first-pact-button'));
    expect(ctaFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(ctaFinder), isA<FilledButton>());
  });

  testWidgets('Android dashboard single-item shortcut shows standalone button with no kebab', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {
        'language_selection_enabled': false,
        'about_screen_enabled': false,
      }),
    ));

    // Only rcOverrides is a kebab candidate in debug → promoted to standalone.
    expect(find.byKey(const Key('kebab-menu-button')), findsNothing);
    expect(find.byKey(const Key('remote-config-debug-button')), findsOneWidget);
  });

  testWidgets('tapping kebab button opens PopupMenu with all enabled items', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await _openKebab(tester);

    expect(find.byKey(const Key('about-button')), findsOneWidget);
    expect(find.byKey(const Key('language-picker-button')), findsOneWidget);
    expect(find.byKey(const Key('remote-config-debug-button')), findsOneWidget);
  });

  testWidgets('tapping kebab button fires KebabMenuOpenedEvent analytics', (tester) async {
    final analyticsService = FakeAnalyticsService();
    await tester.pumpWidget(_buildTestApp(analyticsService: analyticsService));

    await _openKebab(tester);

    expect(
      analyticsService.loggedEvents.whereType<KebabMenuOpenedEvent>(),
      isNotEmpty,
    );
  });

  testWidgets('tapping language item in kebab shows SimpleDialog with language options', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // Dialog title
    expect(find.text('Language'), findsOneWidget);

    // Four language options + system option
    expect(find.text('English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    expect(find.text('Use system language'), findsOneWidget);
  });

  testWidgets('dialog shows check icon on currently selected language', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('de')));

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // German option row should contain a check icon
    final germanRow = find.ancestor(of: find.text('German'), matching: find.byType(Row));
    expect(germanRow, findsOneWidget);
    final checkIcon = find.descendant(of: germanRow, matching: find.byIcon(Icons.check));
    expect(checkIcon, findsOneWidget);
  });

  testWidgets('dialog shows check icon on system option when localeOverride is null', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // System option row should contain a check icon
    final systemRow = find.ancestor(of: find.text('Use system language'), matching: find.byType(Row));
    expect(systemRow, findsOneWidget);
    final checkIcon = find.descendant(of: systemRow, matching: find.byIcon(Icons.check));
    expect(checkIcon, findsOneWidget);
  });

  testWidgets('selecting a language fires analytics and saves locale', (tester) async {
    final analyticsService = FakeAnalyticsService();
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(
      _buildTestApp(analyticsService: analyticsService, localeService: localeService),
    );

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();

    // Analytics: language_change_requested should have been fired when picker opened
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_change_requested'), isTrue);
    // Analytics: language_changed should have been fired after selection
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);

    final changedEvent = analyticsService.loggedEvents.firstWhere((e) => e.name == 'language_changed');
    expect(changedEvent.toParameters()['to_language'], 'de');

    // Locale service should have saved the new locale
    expect(localeService.savedLocale, const Locale('de'));
  });

  testWidgets('selecting system language clears locale override', (tester) async {
    final localeService = FakeLocalePreferenceService();

    // Start with German override
    await tester.pumpWidget(
      _buildTestApp(localeService: localeService, localeOverride: const Locale('de')),
    );

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use system language'));
    await tester.pumpAndSettle();

    // Locale service should have been cleared
    expect(localeService.clearLocaleCallCount, greaterThan(0));
  });

  testWidgets('re-selecting the already-selected language does not fire analytics or save', (tester) async {
    final analyticsService = FakeAnalyticsService();
    final localeService = FakeLocalePreferenceService();

    // German is already selected
    await tester.pumpWidget(
      _buildTestApp(
        analyticsService: analyticsService,
        localeService: localeService,
        localeOverride: const Locale('de'),
      ),
    );

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // Tap the already-selected German option (has a check icon)
    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();

    // language_changed must NOT have been fired
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    // locale service must not have been written
    expect(localeService.savedLocale, isNull);
  });

  testWidgets('selecting system language when already on system is a no-op', (tester) async {
    final localeService = FakeLocalePreferenceService();

    // localeOverride is null — already on system
    await tester.pumpWidget(_buildTestApp(localeService: localeService));

    await _openKebab(tester);
    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use system language'));
    await tester.pumpAndSettle();

    expect(localeService.clearLocaleCallCount, 0);
  });

  testWidgets('tapping language button in carousel (hasPacts=false) shows SimpleDialog', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      hasPacts: false,
      remoteConfig: FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
    ));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
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

    testWidgets('change-name item hidden from kebab when flag is off', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await _openKebab(tester);

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

      await _openKebab(tester);
      expect(find.byKey(const Key('change-name-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const Key('change-name-text-field')));
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

      await _openKebab(tester);
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

      await _openKebab(tester);
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

    testWidgets('save button is disabled while the field is empty', (tester) async {
      await tester.pumpWidget(_buildTestApp(remoteConfig: flagOn));

      await _openKebab(tester);
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), '   ');
      await tester.pump();

      final saveButton = tester.widget<TextButton>(find.byKey(const Key('change-name-save-button')));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('cancel dismisses the dialog without saving', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildTestApp(
        remoteConfig: flagOn,
        userProfileRepository: userProfileRepository,
        seedDisplayName: 'Alex',
      ));

      await _openKebab(tester);
      await tester.tap(find.byKey(const Key('change-name-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change-name-text-field')), 'Sam');
      await tester.tap(find.byKey(const Key('change-name-cancel-button')));
      await tester.pumpAndSettle();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Alex');
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
