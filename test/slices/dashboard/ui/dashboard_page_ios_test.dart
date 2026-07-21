import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

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

  testWidgets('iOS standalone debug button keeps its Semantics label when promoted out of the kebab',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {
        'about_screen_enabled': false,
        'language_selection_enabled': false,
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
