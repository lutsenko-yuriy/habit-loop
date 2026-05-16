import 'dart:async' show Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/analytics/onboarding_analytics_events.dart';

final onboardingViewModelProvider = NotifierProvider.autoDispose<OnboardingViewModel, int>(OnboardingViewModel.new);

class OnboardingViewModel extends AutoDisposeNotifier<int> {
  static const int _slideCount = 4;
  static const int _minAutoAdvanceSeconds = 5;

  Timer? _timer;
  bool _completedFired = false;

  @override
  int build() {
    final effectiveSeconds = _effectiveAutoAdvanceSeconds();
    if (effectiveSeconds > 0) _startTimer(effectiveSeconds);
    ref.onDispose(_cancelTimer);

    unawaited(ref.read(analyticsServiceProvider).logScreenView(OnboardingAnalyticsScreen()));
    _logSlideViewed(0, 'auto');

    return 0;
  }

  int _effectiveAutoAdvanceSeconds() {
    final raw = ref.read(remoteConfigServiceProvider).getInt('onboarding_auto_advance_seconds');
    return raw < _minAutoAdvanceSeconds ? 0 : raw;
  }

  void _startTimer(int seconds) {
    _cancelTimer();
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _advance('auto'));
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Called by the PageView's onPageChanged when the user swipes manually.
  void onUserSwiped(int newIndex) {
    final effectiveSeconds = _effectiveAutoAdvanceSeconds();
    if (effectiveSeconds > 0) _startTimer(effectiveSeconds);
    _goToSlide(newIndex, 'swipe');
  }

  void _advance(String trigger) {
    final current = state;
    if (current >= _slideCount - 1) return;
    _goToSlide(current + 1, trigger);
  }

  void _goToSlide(int index, String trigger) {
    if (index == state) return;
    state = index;
    _logSlideViewed(index, trigger);
    if (index == _slideCount - 1 && !_completedFired) {
      _completedFired = true;
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(OnboardingCompletedEvent(reachedVia: trigger)),
      );
    }
  }

  void _logSlideViewed(int index, String trigger) {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(OnboardingSlideViewedEvent(slideIndex: index, trigger: trigger)),
    );
  }

  void onCreatePactTapped() {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(OnboardingCreatePactTappedEvent(slideIndex: state)),
    );
  }

  void onSignInTapped() {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(OnboardingSignInTappedEvent(slideIndex: state)),
    );
  }
}
