import 'package:habit_loop/analytics/domain/analytics_screen.dart';

/// Screen identifier for the dashboard (home) screen.
class DashboardAnalyticsScreen implements AnalyticsScreen {
  const DashboardAnalyticsScreen();

  @override
  String get name => 'dashboard';
}
