import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/infrastructure/analytics/domain/analytics_screen.dart';

void main() {
  group('ShowupMarkedDoneEvent', () {
    test('has correct name', () {
      final event = ShowupMarkedDoneEvent(pactId: 'pact-123');
      expect(event.name, 'showup_marked_done');
    });

    test('toParameters includes pact_id', () {
      final event = ShowupMarkedDoneEvent(pactId: 'pact-123');
      final params = event.toParameters();
      expect(params['pact_id'], 'pact-123');
    });
  });

  group('ShowupMarkedFailedEvent', () {
    test('has correct name', () {
      final event = ShowupMarkedFailedEvent(pactId: 'pact-456');
      expect(event.name, 'showup_marked_failed');
    });

    test('toParameters includes pact_id', () {
      final event = ShowupMarkedFailedEvent(pactId: 'pact-456');
      final params = event.toParameters();
      expect(params['pact_id'], 'pact-456');
    });
  });

  group('ShowupAutoFailedEvent', () {
    test('has correct name', () {
      final event = ShowupAutoFailedEvent(pactId: 'pact-789');
      expect(event.name, 'showup_auto_failed');
    });

    test('toParameters includes pact_id', () {
      final event = ShowupAutoFailedEvent(pactId: 'pact-789');
      final params = event.toParameters();
      expect(params['pact_id'], 'pact-789');
    });
  });

  group('ShowupDetailAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const ShowupDetailAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('name is showup_detail', () {
      expect(const ShowupDetailAnalyticsScreen().name, 'showup_detail');
    });
  });
}
