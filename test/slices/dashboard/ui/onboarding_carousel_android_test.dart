import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/onboarding_carousel_android.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildCarouselApp({
  int autoAdvanceSeconds = 0,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  Locale? localeOverride,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': autoAdvanceSeconds}),
      ),
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
      locale: locale,
      home: OnboardingCarouselAndroid(onCreatePact: () async {}),
    ),
  );
}

void main() {
  testWidgets('shows first slide title on initial render', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    expect(find.text('Build your habit. For real this time.'), findsOneWidget);
  });

  testWidgets('shows Create a Pact button', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    expect(find.text('Create a Pact'), findsOneWidget);
  });

  testWidgets('shows language picker button', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('swiping left advances to slide 1', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
    await tester.pumpAndSettle();

    expect(find.text('Make a pact with yourself'), findsOneWidget);
    expect(find.text('Build your habit. For real this time.'), findsNothing);
  });

  testWidgets('swiping right returns to slide 0', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    // Advance to slide 1 first
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Make a pact with yourself'), findsOneWidget);

    // Swipe back to slide 0
    await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
    await tester.pumpAndSettle();

    expect(find.text('Build your habit. For real this time.'), findsOneWidget);
  });

  testWidgets('tapping language button shows SimpleDialog with all language options', (tester) async {
    await tester.pumpWidget(_buildCarouselApp());
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    expect(find.text('Use system language'), findsOneWidget);
  });

  testWidgets('selecting language from SimpleDialog saves locale', (tester) async {
    final localeService = FakeLocalePreferenceService();

    await tester.pumpWidget(_buildCarouselApp(
      localeService: localeService,
      localeOverride: const Locale('en'),
    ));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    expect(localeService.savedLocale, const Locale('fr'));
  });

  testWidgets('auto-advances to slide 1 after RC interval', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(autoAdvanceSeconds: 5));
    await tester.pump(); // initial build

    await tester.pump(const Duration(seconds: 5)); // fire the periodic timer
    await tester.pump(const Duration(milliseconds: 600)); // complete page animation

    expect(find.text('Make a pact with yourself'), findsOneWidget);
  });
}
