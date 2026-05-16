import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

final class OnboardingAnalyticsScreen extends AnalyticsScreen {
  @override
  String get name => 'onboarding';
}

final class OnboardingSlideViewedEvent extends AnalyticsEvent {
  OnboardingSlideViewedEvent({required this.slideIndex, required this.trigger});

  final int slideIndex;

  /// `'auto'` for timer-driven advance; `'swipe'` for user-initiated swipe.
  final String trigger;

  @override
  String get name => 'onboarding_slide_viewed';

  @override
  Map<String, Object> toParameters() => {'slide_index': slideIndex, 'trigger': trigger};
}

final class OnboardingCompletedEvent extends AnalyticsEvent {
  OnboardingCompletedEvent({required this.reachedVia});

  /// `'auto'` if the last auto-advance reached slide 3; `'swipe'` if the user swiped to slide 3.
  final String reachedVia;

  @override
  String get name => 'onboarding_completed';

  @override
  Map<String, Object> toParameters() => {'reached_via': reachedVia};
}

final class OnboardingCreatePactTappedEvent extends AnalyticsEvent {
  OnboardingCreatePactTappedEvent({required this.slideIndex});

  final int slideIndex;

  @override
  String get name => 'onboarding_create_pact_tapped';

  @override
  Map<String, Object> toParameters() => {'slide_index': slideIndex};
}

final class OnboardingSignInTappedEvent extends AnalyticsEvent {
  OnboardingSignInTappedEvent({required this.slideIndex});

  final int slideIndex;

  @override
  String get name => 'onboarding_sign_in_tapped';

  @override
  Map<String, Object> toParameters() => {'slide_index': slideIndex};
}
