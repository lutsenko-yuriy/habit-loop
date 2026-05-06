import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';

Widget _buildTestApp({
  bool hasPacts = true,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  Locale? localeOverride,
}) {
  return ProviderScope(
    overrides: [
      pactListViewModelProvider.overrideWith(_LoadedPactListViewModel.new),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (localeService != null) localePreferenceServiceProvider.overrideWithValue(localeService),
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
      locale: const Locale('en'),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: DashboardPageIos(
          state: const DashboardState(isLoading: false),
          hasPacts: hasPacts,
          onDaySelected: (_) {},
          onCreatePact: () async {},
          onShowupTapped: (_) async {},
        ),
      ),
    ),
  );
}

void main() {
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

  testWidgets('iOS dashboard shows globe icon button in navigation bar', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.byKey(const Key('language-picker-button')), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
  });

  testWidgets('iOS dashboard globe icon visible even when hasPacts is false', (tester) async {
    await tester.pumpWidget(_buildTestApp(hasPacts: false));

    expect(find.byKey(const Key('language-picker-button')), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
  });

  testWidgets('tapping globe icon shows CupertinoActionSheet with language options', (tester) async {
    // Use a specific locale override so system option does not have checkmark,
    // allowing plain text matching for all options.
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('en')));

    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // Action sheet title
    expect(find.text('Language'), findsOneWidget);

    // Four language options (English has checkmark since it's selected)
    expect(find.text('✓ English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    expect(find.text('Use system language'), findsOneWidget);

    // Cancel button
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('action sheet shows checkmark on currently selected language', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeOverride: const Locale('fr')));

    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // The French option should have a leading checkmark
    expect(find.text('✓ French'), findsOneWidget);
    // English should not have a checkmark
    expect(find.text('✓ English'), findsNothing);
  });

  testWidgets('action sheet shows checkmark on system option when localeOverride is null', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // When localeOverrideProvider is null, system option should have checkmark
    expect(find.text('✓ Use system language'), findsOneWidget);
  });

  testWidgets('selecting a language from action sheet fires analytics and updates locale provider', (tester) async {
    final analyticsService = FakeAnalyticsService();
    final localeService = FakeLocalePreferenceService();

    // Start with English override so French has no checkmark and can be tapped by plain text
    await tester.pumpWidget(
      _buildTestApp(
        analyticsService: analyticsService,
        localeService: localeService,
        localeOverride: const Locale('en'),
      ),
    );

    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    // Analytics: language_change_requested should have been fired when the picker opened
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_change_requested'), isTrue);
    // Analytics: language_changed should have been fired after selection
    expect(analyticsService.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);

    final changedEvent = analyticsService.loggedEvents.firstWhere((e) => e.name == 'language_changed');
    expect(changedEvent.toParameters()['to_language'], 'fr');

    // Locale service should have saved the new locale
    expect(localeService.savedLocale, const Locale('fr'));
  });

  testWidgets('selecting system language clears locale override', (tester) async {
    final localeService = FakeLocalePreferenceService();

    // Start with French override
    await tester.pumpWidget(
      _buildTestApp(localeService: localeService, localeOverride: const Locale('fr')),
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

    // English is already selected
    await tester.pumpWidget(
      _buildTestApp(
        analyticsService: analyticsService,
        localeService: localeService,
        localeOverride: const Locale('en'),
      ),
    );

    await tester.tap(find.byKey(const Key('language-picker-button')));
    await tester.pumpAndSettle();

    // Tap the already-selected English option (shows with checkmark)
    await tester.tap(find.text('✓ English'));
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

    await tester.tap(find.text('✓ Use system language'));
    await tester.pumpAndSettle();

    expect(localeService.clearLocaleCallCount, 0);
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
