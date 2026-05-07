import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';

void main() {
  group('applyLanguageSelection', () {
    late FakeAnalyticsService analytics;
    late FakeLocalePreferenceService localeService;

    setUp(() {
      analytics = FakeAnalyticsService();
      localeService = FakeLocalePreferenceService();
    });

    test('saves locale and fires analytics when a different language is selected', () async {
      Locale? capturedLocale;

      await applyLanguageSelection(
        selectedLocale: const Locale('fr'),
        currentOverride: const Locale('en'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (locale) => capturedLocale = locale,
      );

      expect(localeService.savedLocale, const Locale('fr'));
      expect(capturedLocale, const Locale('fr'));
      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);
      final event = analytics.loggedEvents.firstWhere((e) => e.name == 'language_changed');
      expect(event.toParameters()['from_language'], 'en');
      expect(event.toParameters()['to_language'], 'fr');
    });

    test('no-ops when re-selecting the current language override', () async {
      bool updateCalled = false;

      await applyLanguageSelection(
        selectedLocale: const Locale('fr'),
        currentOverride: const Locale('fr'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) => updateCalled = true,
      );

      // Nothing should have happened
      expect(localeService.savedLocale, isNull);
      expect(updateCalled, isFalse);
      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    });

    test('clears locale when system language is selected and override was set', () async {
      Locale? providerValue = const Locale('de'); // simulate initial state

      await applyLanguageSelection(
        selectedLocale: null, // null = system
        currentOverride: const Locale('de'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (locale) => providerValue = locale,
      );

      expect(localeService.clearLocaleCallCount, 1);
      expect(providerValue, isNull);
    });

    test('no-ops when system language is selected and override is already null', () async {
      bool updateCalled = false;

      await applyLanguageSelection(
        selectedLocale: null, // null = system
        currentOverride: null, // already on system
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) => updateCalled = true,
      );

      expect(localeService.clearLocaleCallCount, 0);
      expect(updateCalled, isFalse);
    });

    test('does not fire language_changed when clearing to system language', () async {
      await applyLanguageSelection(
        selectedLocale: null,
        currentOverride: const Locale('de'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) {},
      );

      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // openLanguagePicker — end-to-end with a fake showPicker
  // ---------------------------------------------------------------------------
  group('openLanguagePicker', () {
    testWidgets('fires language_change_requested and screen view before showing picker', (tester) async {
      final analytics = FakeAnalyticsService();
      final localeService = FakeLocalePreferenceService();
      List<({String label, Locale? locale})>? capturedOptions;
      Locale? capturedOverride;

      await tester.pumpWidget(
        _buildTestApp(
          analyticsService: analytics,
          localeService: localeService,
          localeOverride: const Locale('en'),
          child: _PickerTrigger(
            showPicker: ({required context, required options, required currentOverride}) async {
              capturedOptions = options;
              capturedOverride = currentOverride;
              return null; // dismissed
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(analytics.loggedEvents.any((e) => e.name == 'language_change_requested'), isTrue);
      expect(analytics.loggedScreens.any((s) => s.name == 'language_picker'), isTrue);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.length, 5); // en, fr, de, ru, system
      expect(capturedOverride, const Locale('en'));
    });

    testWidgets('options list contains all four languages and the system option', (tester) async {
      List<({String label, Locale? locale})>? capturedOptions;

      await tester.pumpWidget(
        _buildTestApp(
          child: _PickerTrigger(
            showPicker: ({required context, required options, required currentOverride}) async {
              capturedOptions = options;
              return null;
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      final locales = capturedOptions!.map((o) => o.locale).toList();
      expect(locales.contains(const Locale('en')), isTrue);
      expect(locales.contains(const Locale('fr')), isTrue);
      expect(locales.contains(const Locale('de')), isTrue);
      expect(locales.contains(const Locale('ru')), isTrue);
      expect(locales.contains(null), isTrue); // system option
    });

    testWidgets('when picker returns a locale, applyLanguageSelection is called', (tester) async {
      final analytics = FakeAnalyticsService();
      final localeService = FakeLocalePreferenceService();

      await tester.pumpWidget(
        _buildTestApp(
          analyticsService: analytics,
          localeService: localeService,
          localeOverride: const Locale('en'),
          child: _PickerTrigger(
            showPicker: ({required context, required options, required currentOverride}) async {
              return const Locale('fr'); // user picked French
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(localeService.savedLocale, const Locale('fr'));
      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);
      final changedEvent = analytics.loggedEvents.firstWhere((e) => e.name == 'language_changed');
      expect(changedEvent.toParameters()['to_language'], 'fr');
    });

    testWidgets('when picker returns null (system), clearLocale is called if override was set', (tester) async {
      final localeService = FakeLocalePreferenceService();

      await tester.pumpWidget(
        _buildTestApp(
          localeService: localeService,
          localeOverride: const Locale('de'),
          child: _PickerTrigger(
            showPicker: ({required context, required options, required currentOverride}) async {
              return null; // user picked system (picker returns null for system)
            },
          ),
        ),
      );

      // Note: when showPicker returns null it could mean "dismissed" OR "system selected".
      // The openLanguagePicker contract passes null to applyLanguageSelection.
      // To test the system-selected path we need the picker to signal "system" by returning null.
      // Platform pickers distinguish dismiss vs system internally; openLanguagePicker receives
      // null from both scenarios and defers to applyLanguageSelection which no-ops if already null.
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Dismissed (null) is passed through — applyLanguageSelection no-ops on already-null,
      // but here override is 'de' so clearLocale should be called.
      expect(localeService.clearLocaleCallCount, 1);
    });

    testWidgets('no-op when picker is dismissed and same language re-selected would be filtered', (tester) async {
      final localeService = FakeLocalePreferenceService();
      bool pickerCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          localeService: localeService,
          child: _PickerTrigger(
            showPicker: ({required context, required options, required currentOverride}) async {
              pickerCalled = true;
              return null; // null => system; since override is already null → no-op in apply
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(pickerCalled, isTrue);
      // localeOverride is null → selecting system is a no-op
      expect(localeService.clearLocaleCallCount, 0);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

typedef _ShowPickerCallback = Future<Locale?> Function({
  required BuildContext context,
  required List<({String label, Locale? locale})> options,
  required Locale? currentOverride,
});

/// Minimal widget that calls [openLanguagePicker] when tapped.
class _PickerTrigger extends ConsumerWidget {
  const _PickerTrigger({required this.showPicker});

  final _ShowPickerCallback showPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => openLanguagePicker(context: context, ref: ref, showPicker: showPicker),
      child: const Text('Open Picker'),
    );
  }
}

Widget _buildTestApp({
  required Widget child,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  Locale? localeOverride,
}) {
  return ProviderScope(
    overrides: [
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
      home: Scaffold(body: child),
    ),
  );
}
