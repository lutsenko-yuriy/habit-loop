import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

class AboutAnalyticsScreen implements AnalyticsScreen {
  const AboutAnalyticsScreen();

  @override
  String get name => 'about';
}

class FeedbackTappedEvent implements AnalyticsEvent {
  const FeedbackTappedEvent();

  @override
  String get name => 'feedback_tapped';

  @override
  Map<String, Object?> toParameters() => const {};
}
