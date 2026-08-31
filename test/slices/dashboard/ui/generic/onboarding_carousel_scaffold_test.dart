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
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';

import '../../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

Widget _buildApp({
  Color inactiveDotColor = Colors.grey,
  Widget Function(BuildContext, bool isSigningIn, bool isAnonymous)? buildActions,
  bool isSigningIn = false,
  bool isAnonymous = true,
  int autoAdvanceSeconds = 0,
  String? personalizedName,
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
      personalizedNameProvider.overrideWithValue(personalizedName),
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
          find.text(OnboardingSlide.slides[0].title(
            AppLocalizations.of(tester.element(find.byType(PageView)))!,
            null,
          )),
          findsOneWidget);
    });

    testWidgets('swiping left advances to slide 1', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(OnboardingDotsRow)))!;
      expect(find.text(OnboardingSlide.slides[1].title(l10n, null)), findsOneWidget);
    });
  });

  group('OnboardingCarouselScaffold — personalization (HAB-232 WU6)', () {
    testWidgets('slide 0 title is personalized when personalizedNameProvider returns a name', (tester) async {
      await tester.pumpWidget(_buildApp(personalizedName: 'Alex'));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(PageView)))!;
      expect(find.text(l10n.onboardingSlide0TitlePersonalized('Alex')), findsOneWidget);
      expect(find.text(l10n.onboardingSlide0Title), findsNothing);
    });

    testWidgets('slide 0 title falls back to neutral copy when personalizedNameProvider returns null', (tester) async {
      await tester.pumpWidget(_buildApp(personalizedName: null));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(PageView)))!;
      expect(find.text(l10n.onboardingSlide0Title), findsOneWidget);
    });

    testWidgets(
        'a long personalized name does not overflow OnboardingSlideWidget on a tight slot (HAB-232 WU6 regression)',
        (tester) async {
      // Reproduces the exact fixed-size slot CI's headless run reported
      // (w=256, h=148) before the title/body were moved into a
      // Flexible+SingleChildScrollView.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 256,
            height: 148,
            child: OnboardingSlideWidget(
              slide: OnboardingSlide.slides[0],
              l10n: l10n,
              personalizedName: 'A' * 40, // max name length — forces a multi-line title
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'normal-length copy is not force-scrolled on a real small-device slot '
        '(regression — an earlier fix inflated the reported intrinsic height by ~100px, '
        'pushing content off-screen on short viewports)', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      for (final slide in OnboardingSlide.slides) {
        // 360x420 — the actual PageView slide slot on a ~360x640 device
        // (HAB-232 WU6 audit), not an arbitrarily generous size. The earlier
        // Flexible-spacer version reported maxScrollExtent 72 here even
        // though real content only needs 374px.
        //
        // This slot has only ~4px of headroom over slide 1's English copy
        // (416px) — if a future copy change flips this red, that's a real
        // signal to check the actual device slot, not a cue to loosen this
        // assertion back toward masking the original bug.
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 420,
              child: OnboardingSlideWidget(slide: slide, l10n: l10n),
            ),
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(
          scrollable.position.maxScrollExtent,
          0,
          reason: 'content that already fits the slot should not need to scroll — a non-zero '
              'maxScrollExtent here means the image/title/body are being squeezed into less '
              'height than they actually need',
        );
      }
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
