import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/analytics/dashboard_screens.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/infrastructure/analytics/data/noop_analytics_service.dart';

void main() {
  group('NoopAnalyticsService', () {
    late NoopAnalyticsService service;

    setUp(() {
      service = NoopAnalyticsService();
    });

    test('logEvent does not throw for any event', () async {
      final events = [
        PactCreatedEvent(
          scheduleType: 'daily',
          durationDays: 180,
          showupDurationMinutes: 10,
          showupsExpected: 180,
        ),
        ShowupMarkedDoneEvent(pactId: 'p1'),
        ShowupMarkedFailedEvent(pactId: 'p2'),
        ShowupAutoFailedEvent(pactId: 'p3'),
        PactStoppedEvent(
          daysActive: 10,
          totalShowupsDone: 5,
          totalShowupsFailed: 2,
          totalShowupsRemaining: 3,
        ),
      ];
      for (final event in events) {
        await expectLater(service.logEvent(event), completes);
      }
    });

    test('logScreenView does not throw for any screen', () async {
      final screens = [
        const DashboardAnalyticsScreen(),
        const PactCreationAnalyticsScreen(),
        const PactDetailAnalyticsScreen(),
        const ShowupDetailAnalyticsScreen(),
      ];
      for (final screen in screens) {
        await expectLater(service.logScreenView(screen), completes);
      }
    });
  });
}
