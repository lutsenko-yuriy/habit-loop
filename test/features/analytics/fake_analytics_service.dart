import 'package:habit_loop/features/analytics/domain/analytics_event.dart';
import 'package:habit_loop/features/analytics/domain/analytics_screen.dart';
import 'package:habit_loop/features/analytics/domain/analytics_service.dart';

/// A fake [AnalyticsService] that records all logged events and screens.
/// Use in tests that need to assert on analytics calls without touching Firebase.
class FakeAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> loggedEvents = [];
  final List<AnalyticsScreen> loggedScreens = [];

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    loggedEvents.add(event);
  }

  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    loggedScreens.add(screen);
  }

  void reset() {
    loggedEvents.clear();
    loggedScreens.clear();
  }
}
