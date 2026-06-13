import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/onboarding_carousel_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

// ---------------------------------------------------------------------------
// Fake SyncStatusViewModel for _onSignIn polling tests
// ---------------------------------------------------------------------------

class _FakeSyncStatusViewModel extends AutoDisposeNotifier<SyncUiState> implements SyncStatusViewModel {
  @override
  SyncUiState build() => SyncUiState.synced;

  @override
  Future<void> linkWithGoogle() async {}

  @override
  Future<void> triggerManualSync() async {}

  @override
  Future<int> fullSync() async => 0;

  @override
  Future<void> signOut() async {}
}

Widget _buildCarouselApp({
  int autoAdvanceSeconds = 0,
  FakeAnalyticsService? analyticsService,
  FakeLocalePreferenceService? localeService,
  Locale? localeOverride,
  Locale locale = const Locale('en'),
  bool isSigningIn = false,
  Map<String, dynamic> rcOverrides = const {},
}) {
  return ProviderScope(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {
          'onboarding_auto_advance_seconds': autoAdvanceSeconds,
          ...rcOverrides,
        }),
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

  testWidgets('shows Sign in with Google button when not signing in', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(isSigningIn: false));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hides Sign in button and shows spinner when signing in', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(isSigningIn: true));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  group('_onSignIn polling: isSigningIn stays true until hasActivePactsProvider settles', () {
    Widget buildSignInPollingApp(Completer<bool> pactsCompleter) {
      return ProviderScope(
        overrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
          ),
          syncStatusViewModelProvider.overrideWith(_FakeSyncStatusViewModel.new),
          hasActivePactsProvider.overrideWith((ref) => pactsCompleter.future),
          authStateChangesProvider.overrideWith(
            (ref) => Stream.value(const AuthState(userId: 'anon-1', isAnonymous: true)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingCarouselAndroid(onCreatePact: () async {}),
        ),
      );
    }

    testWidgets('isSigningIn stays true while hasActivePactsProvider is loading', (tester) async {
      final completer = Completer<bool>();
      await tester.pumpWidget(buildSignInPollingApp(completer));
      await tester.pump();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump(); // triggers _onSignIn, sets isSigningIn = true

      // linkWithGoogle returns immediately; microtask yield fires
      await tester.pump(Duration.zero);

      // hasActivePactsProvider is still loading — spinner must be visible
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Sign in with Google'), findsNothing);

      // Clean up: settle the provider so the polling loop exits before widget dispose
      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('isSigningIn resets to false after hasActivePactsProvider settles to data', (tester) async {
      final completer = Completer<bool>();
      await tester.pumpWidget(buildSignInPollingApp(completer));
      await tester.pump();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();
      await tester.pump(Duration.zero);

      // Spinner while loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Settle the provider
      completer.complete(false); // no pacts yet
      await tester.pumpAndSettle();

      // isSigningIn should be false — sign-in button re-appears
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('isSigningIn resets to false if hasActivePactsProvider settles to error', (tester) async {
      final completer = Completer<bool>();
      await tester.pumpWidget(buildSignInPollingApp(completer));
      await tester.pump();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Settle the provider with an error — loop must exit and reset flag
      completer.completeError(Exception('db error'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('hides language button when language_selection_enabled is false', (tester) async {
    await tester.pumpWidget(_buildCarouselApp(rcOverrides: {'language_selection_enabled': false}));
    await tester.pump();

    expect(find.text('Language'), findsNothing);
  });
}
