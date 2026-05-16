import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  Map<String, dynamic>? rcOverrides,
  FakeAnalyticsService? analytics,
}) {
  return ProviderContainer(overrides: [
    remoteConfigServiceProvider.overrideWithValue(
      FakeRemoteConfigService(overrides: rcOverrides ?? {}),
    ),
    analyticsServiceProvider.overrideWithValue(analytics ?? FakeAnalyticsService()),
  ]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OnboardingViewModel', () {
    // -------------------------------------------------------------------------
    // Initial state and build-time analytics
    // -------------------------------------------------------------------------

    group('build', () {
      test('initial state is slide 0', () {
        final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 0});
        addTearDown(container.dispose);
        expect(container.read(onboardingViewModelProvider), 0);
      });

      test('logs the onboarding screen view', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        expect(analytics.loggedScreens.any((s) => s.name == 'onboarding'), isTrue);
      });

      test('fires onboarding_slide_viewed with slide_index 0 and trigger initial', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        final event = analytics.loggedEvents.firstWhere((e) => e.name == 'onboarding_slide_viewed');
        expect(event.toParameters()['slide_index'], 0);
        expect(event.toParameters()['trigger'], 'initial');
      });
    });

    // -------------------------------------------------------------------------
    // Auto-advance threshold: raw < 5 → timer disabled
    // -------------------------------------------------------------------------

    group('_effectiveAutoAdvanceSeconds', () {
      test('timer does not start when RC value is 0', () {
        fakeAsync((async) {
          final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 0});
          // keep the provider alive with an active listener so auto-dispose does not fire
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          async.elapse(const Duration(seconds: 30));
          expect(container.read(onboardingViewModelProvider), 0);
          container.dispose();
        });
      });

      test('timer does not start when RC value is 4 (below minimum of 5)', () {
        fakeAsync((async) {
          final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 4});
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          async.elapse(const Duration(seconds: 4));
          expect(container.read(onboardingViewModelProvider), 0);
          container.dispose();
        });
      });

      test('timer starts and advances when RC value is exactly 5', () {
        fakeAsync((async) {
          final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 5});
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          async.elapse(const Duration(seconds: 5));
          expect(container.read(onboardingViewModelProvider), 1);
          container.dispose();
        });
      });
    });

    // -------------------------------------------------------------------------
    // Timer-driven auto-advance
    // -------------------------------------------------------------------------

    group('auto-advance timer', () {
      test('fires onboarding_slide_viewed with trigger auto on each tick', () {
        fakeAsync((async) {
          final analytics = FakeAnalyticsService();
          final container = _makeContainer(
            rcOverrides: {'onboarding_auto_advance_seconds': 5},
            analytics: analytics,
          );
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          analytics.reset(); // clear the initial slide-viewed event

          async.elapse(const Duration(seconds: 5));

          expect(
            analytics.loggedEvents.any(
              (e) => e.name == 'onboarding_slide_viewed' && e.toParameters()['trigger'] == 'auto',
            ),
            isTrue,
          );
          container.dispose();
        });
      });

      test('advances through all slides and stops at the last one', () {
        fakeAsync((async) {
          final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 5});
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);

          // 4 slides → 3 advances needed (slide 0 → 1 → 2 → 3)
          async.elapse(const Duration(seconds: 15));

          expect(container.read(onboardingViewModelProvider), 3);
          container.dispose();
        });
      });

      test('timer is cancelled at last slide — no further advances', () {
        fakeAsync((async) {
          final analytics = FakeAnalyticsService();
          final container = _makeContainer(
            rcOverrides: {'onboarding_auto_advance_seconds': 5},
            analytics: analytics,
          );
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          async.elapse(const Duration(seconds: 15)); // reach last slide
          expect(container.read(onboardingViewModelProvider), 3);

          analytics.reset();
          async.elapse(const Duration(seconds: 30)); // well past next tick

          expect(container.read(onboardingViewModelProvider), 3);
          expect(analytics.loggedEvents.where((e) => e.name == 'onboarding_slide_viewed'), isEmpty);
          container.dispose();
        });
      });
    });

    // -------------------------------------------------------------------------
    // onboarding_completed guard
    // -------------------------------------------------------------------------

    group('onboarding_completed event', () {
      test('fires with reached_via auto when auto-advance reaches last slide', () {
        fakeAsync((async) {
          final analytics = FakeAnalyticsService();
          final container = _makeContainer(
            rcOverrides: {'onboarding_auto_advance_seconds': 5},
            analytics: analytics,
          );
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);
          async.elapse(const Duration(seconds: 15));

          final events = analytics.loggedEvents.where((e) => e.name == 'onboarding_completed');
          expect(events, hasLength(1));
          expect(events.first.toParameters()['reached_via'], 'auto');
          container.dispose();
        });
      });

      test('fires only once even when user swipes back to last slide again', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);

        // First time at last slide
        container.read(onboardingViewModelProvider.notifier).onUserSwiped(3);
        expect(
          analytics.loggedEvents.where((e) => e.name == 'onboarding_completed'),
          hasLength(1),
        );

        // Navigate away then back — guard must block a second firing
        container.read(onboardingViewModelProvider.notifier).onUserSwiped(1);
        container.read(onboardingViewModelProvider.notifier).onUserSwiped(3);

        expect(
          analytics.loggedEvents.where((e) => e.name == 'onboarding_completed'),
          hasLength(1),
        );
      });

      test('fires with reached_via swipe when user swipes to last slide', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);

        container.read(onboardingViewModelProvider.notifier).onUserSwiped(3);

        final events = analytics.loggedEvents.where((e) => e.name == 'onboarding_completed');
        expect(events, hasLength(1));
        expect(events.first.toParameters()['reached_via'], 'swipe');
      });
    });

    // -------------------------------------------------------------------------
    // onUserSwiped
    // -------------------------------------------------------------------------

    group('onUserSwiped', () {
      test('updates state and logs slide_viewed with swipe trigger', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        analytics.reset();

        container.read(onboardingViewModelProvider.notifier).onUserSwiped(2);

        expect(container.read(onboardingViewModelProvider), 2);
        final slideEvent = analytics.loggedEvents.firstWhere((e) => e.name == 'onboarding_slide_viewed');
        expect(slideEvent.toParameters()['slide_index'], 2);
        expect(slideEvent.toParameters()['trigger'], 'swipe');
      });

      test('does nothing when called with the current slide index', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        analytics.reset();

        container.read(onboardingViewModelProvider.notifier).onUserSwiped(0); // already at 0

        expect(container.read(onboardingViewModelProvider), 0);
        expect(analytics.loggedEvents.where((e) => e.name == 'onboarding_slide_viewed'), isEmpty);
      });

      test('restarts the auto-advance timer from zero', () {
        fakeAsync((async) {
          final container = _makeContainer(rcOverrides: {'onboarding_auto_advance_seconds': 5});
          container.listen(onboardingViewModelProvider, (_, __) {}, fireImmediately: true);

          // User swipes at t=3s — timer resets
          async.elapse(const Duration(seconds: 3));
          container.read(onboardingViewModelProvider.notifier).onUserSwiped(1);
          expect(container.read(onboardingViewModelProvider), 1);

          // 5s after the swipe (t=8s) the timer fires and advances to slide 2
          async.elapse(const Duration(seconds: 5));
          expect(container.read(onboardingViewModelProvider), 2);
          container.dispose();
        });
      });
    });

    // -------------------------------------------------------------------------
    // onCreatePactTapped
    // -------------------------------------------------------------------------

    group('onCreatePactTapped', () {
      test('fires onboarding_create_pact_tapped with current slide index', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        container.read(onboardingViewModelProvider.notifier).onUserSwiped(2);
        analytics.reset();

        container.read(onboardingViewModelProvider.notifier).onCreatePactTapped();

        final event = analytics.loggedEvents.firstWhere((e) => e.name == 'onboarding_create_pact_tapped');
        expect(event.toParameters()['slide_index'], 2);
      });
    });

    // -------------------------------------------------------------------------
    // onSignInTapped
    // -------------------------------------------------------------------------

    group('onSignInTapped', () {
      test('fires onboarding_sign_in_tapped with current slide index', () {
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          rcOverrides: {'onboarding_auto_advance_seconds': 0},
          analytics: analytics,
        );
        addTearDown(container.dispose);
        container.read(onboardingViewModelProvider);
        container.read(onboardingViewModelProvider.notifier).onUserSwiped(1);
        analytics.reset();

        container.read(onboardingViewModelProvider.notifier).onSignInTapped();

        final event = analytics.loggedEvents.firstWhere((e) => e.name == 'onboarding_sign_in_tapped');
        expect(event.toParameters()['slide_index'], 1);
      });
    });
  });
}
