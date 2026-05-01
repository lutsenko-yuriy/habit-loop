import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Screen identifier for the dashboard (home) screen.
class DashboardAnalyticsScreen implements AnalyticsScreen {
  const DashboardAnalyticsScreen();

  @override
  String get name => 'dashboard';
}
