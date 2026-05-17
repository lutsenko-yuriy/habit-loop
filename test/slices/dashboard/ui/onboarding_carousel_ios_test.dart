import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/onboarding_carousel_ios.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildCarouselApp({
  int autoAdvanceSeconds = 0,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  Locale? localeOverride,
  Locale locale = const Locale('en'),
  bool isSigningIn = false,
}) {
  return ProviderScope(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': autoAdvanceSeconds}),
      ),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (localeService != null) localePreferenceServiceProvider.overrideWithValue(localeService),
      if (localeOverride != null) localeOverrideProvider.overrideWith((ref) => localeOverride),
      onboardingSignInLoadingProvider.overrideWith((ref) => isSigningIn),
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
        child: OnboardingCarouselIos(onCreatePact: () async {}),
      ),
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

  testWidgets('tapping language button shows CupertinoActionSheet with all language options', (tester) async {
    // Set English override so the selected item shows with checkmark and others are plain text
    await tester.pumpWidget(_buildCarouselApp(localeOverride: const Locale('en')));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('✓ English'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    expect(find.text('Use system language'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('selecting language from CupertinoActionSheet saves locale', (tester) async {
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

  testWidgets('shows Sign in with Google button when not signing in', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(isSigningIn: false));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('hides Sign in button and shows spinner when signing in', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(isSigningIn: true));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsWidgets);
  });
}
