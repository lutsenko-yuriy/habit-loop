import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';

void main() {
  group('PactTimelineAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(
        const PactTimelineAnalyticsScreen(pactId: 'p1', pactStatus: 'active', totalShowupCount: 5),
        isA<AnalyticsScreen>(),
      );
    });

    test('name is pact_timeline', () {
      expect(
        const PactTimelineAnalyticsScreen(pactId: 'p1', pactStatus: 'active', totalShowupCount: 0).name,
        'pact_timeline',
      );
    });

    test('exposes pactId, pactStatus, totalShowupCount', () {
      const screen = PactTimelineAnalyticsScreen(pactId: 'abc', pactStatus: 'completed', totalShowupCount: 42);
      expect(screen.pactId, 'abc');
      expect(screen.pactStatus, 'completed');
      expect(screen.totalShowupCount, 42);
    });

    test('valid pactStatus values', () {
      for (final status in ['active', 'completed', 'stopped']) {
        final screen = PactTimelineAnalyticsScreen(pactId: 'p1', pactStatus: status, totalShowupCount: 0);
        expect(screen.pactStatus, status);
      }
    });
  });

  group('PactTimelineMilestoneTappedEvent', () {
    test('has correct name', () {
      final event = PactTimelineMilestoneTappedEvent(pactId: 'p1', itemType: 'noted_showup');
      expect(event.name, 'pact_timeline_milestone_tapped');
    });

    test('toParameters includes pact_id and item_type', () {
      final event = PactTimelineMilestoneTappedEvent(pactId: 'abc', itemType: 'single_showup');
      final params = event.toParameters();
      expect(params['pact_id'], 'abc');
      expect(params['item_type'], 'single_showup');
    });

    test('valid item_type values', () {
      for (final type in ['noted_showup', 'single_showup']) {
        final event = PactTimelineMilestoneTappedEvent(pactId: 'p1', itemType: type);
        expect(event.toParameters()['item_type'], type);
      }
    });

    test('toParameters contains exactly two keys', () {
      final event = PactTimelineMilestoneTappedEvent(pactId: 'p1', itemType: 'noted_showup');
      expect(event.toParameters().length, 2);
    });
  });
}
