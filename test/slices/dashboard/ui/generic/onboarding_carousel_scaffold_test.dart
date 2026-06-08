import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_scaffold.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_widgets.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';

import '../../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildApp({
  Color inactiveDotColor = Colors.grey,
  Widget Function(BuildContext, bool isSigningIn, bool isAnonymous)? buildActions,
  bool isSigningIn = false,
  bool isAnonymous = true,
  int autoAdvanceSeconds = 0,
}) {
  return ProviderScope(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': autoAdvanceSeconds}),
      ),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      onboardingSignInLoadingProvider.overrideWith((ref) => isSigningIn),
      authStateChangesProvider.overrideWith(
        (ref) => Stream.value(AuthState(userId: 'u-1', isAnonymous: isAnonymous)),
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
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
        ),
        child: Scaffold(
          body: SafeArea(
            child: OnboardingCarouselScaffold(
              onCreatePact: () async {},
              inactiveDotColor: inactiveDotColor,
              buildActions: buildActions ??
                  (ctx, isSigningIn, isAnonymous) => SizedBox(
                        key: Key('actions-isSigningIn:$isSigningIn-isAnonymous:$isAnonymous'),
                      ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('OnboardingCarouselScaffold — PageView', () {
    testWidgets('renders PageView with slide count', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('first slide title is visible on initial render', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(
          find.text(OnboardingSlide.slides[0].title(AppLocalizations.of(
            tester.element(find.byType(PageView)),
          )!)),
          findsOneWidget);
    });

    testWidgets('swiping left advances to slide 1', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(OnboardingDotsRow)))!;
      expect(find.text(OnboardingSlide.slides[1].title(l10n)), findsOneWidget);
    });
  });

  group('OnboardingCarouselScaffold — dots row', () {
    testWidgets('renders OnboardingDotsRow with slide count', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      final dots = tester.widget<OnboardingDotsRow>(find.byType(OnboardingDotsRow));
      expect(dots.count, OnboardingSlide.slides.length);
    });

    testWidgets('passes inactiveDotColor to OnboardingDotsRow', (tester) async {
      await tester.pumpWidget(_buildApp(inactiveDotColor: Colors.red));
      await tester.pump();
      final dots = tester.widget<OnboardingDotsRow>(find.byType(OnboardingDotsRow));
      expect(dots.inactiveDotColor, Colors.red);
    });
  });

  group('OnboardingCarouselScaffold — buildActions slot', () {
    testWidgets('passes isSigningIn=false and isAnonymous=true by default', (tester) async {
      await tester.pumpWidget(_buildApp(isSigningIn: false, isAnonymous: true));
      await tester.pump();
      expect(find.byKey(const Key('actions-isSigningIn:false-isAnonymous:true')), findsOneWidget);
    });

    testWidgets('passes isSigningIn=true when provider is true', (tester) async {
      await tester.pumpWidget(_buildApp(isSigningIn: true, isAnonymous: true));
      await tester.pump();
      expect(find.byKey(const Key('actions-isSigningIn:true-isAnonymous:true')), findsOneWidget);
    });

    testWidgets('passes isAnonymous=false when user is not anonymous', (tester) async {
      await tester.pumpWidget(_buildApp(isSigningIn: false, isAnonymous: false));
      await tester.pump();
      expect(find.byKey(const Key('actions-isSigningIn:false-isAnonymous:false')), findsOneWidget);
    });
  });
}
