import 'package:flutter/material.dart';
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
import 'package:habit_loop/slices/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

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
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
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
      home: DashboardPageAndroid(
        state: state,
        hasPacts: hasPacts,
        showCarousel: !hasPacts,
        onDaySelected: (_) {},
        onCreatePact: () async {},
        onShowupTapped: (_) async {},
      ),
    ),
  );
}

void main() {
  testWidgets('Android dashboard shows language globe icon in app bar', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('language-picker-button')), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
  });

  testWidgets('Android dashboard hides sync button when network_sync_enabled is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'network_sync_enabled': false}),
    ));

    expect(find.byKey(const Key('sync-status-button')), findsNothing);
  });

  testWidgets('Android dashboard hides language button when language_selection_enabled is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      remoteConfig: FakeRemoteConfigService(overrides: {'language_selection_enabled': false}),
    ));

    expect(find.byKey(const Key('language-picker-button')), findsNothing);
    expect(find.byIcon(Icons.language), findsNothing);
  });

  testWidgets('Android dashboard shows onboarding carousel when hasPacts is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      hasPacts: false,
      remoteConfig: FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
    ));

    // Carousel replaces the regular scaffold — no app bar or language-picker-button.
    expect(find.byKey(const Key('language-picker-button')), findsNothing);
    expect(find.text('Create a Pact'), findsOneWidget);
  });

  testWidgets('tapping globe icon shows SimpleDialog with language options', (tester) async {
    await tester.pumpWidget(_buildTestApp());

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
