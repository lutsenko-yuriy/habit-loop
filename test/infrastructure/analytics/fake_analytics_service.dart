import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';

/// A fake [AnalyticsService] that records all logged events and screens.
/// Use in tests that need to assert on analytics calls without touching Firebase.
class FakeAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> loggedEvents = [];
  final List<AnalyticsScreen> loggedScreens = [];
  final List<({String name, String? value})> setUserProperties = [];

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    loggedEvents.add(event);
  }

  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    loggedScreens.add(screen);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    setUserProperties.add((name: name, value: value));
  }

  void reset() {
    loggedEvents.clear();
    loggedScreens.clear();
    setUserProperties.clear();
  }
}
