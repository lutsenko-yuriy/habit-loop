import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/slices/dashboard/analytics/dashboard_screens.dart';

void main() {
  group('DashboardAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const DashboardAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is dashboard', () {
      expect(const DashboardAnalyticsScreen().name, 'dashboard');
    });

    test('const construction works', () {
      const a = DashboardAnalyticsScreen();
      const b = DashboardAnalyticsScreen();
      // Both are valid AnalyticsScreen instances with the same name.
      expect(a.name, b.name);
    });
  });
}
