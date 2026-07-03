import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';

void main() {
  group('NotificationsScheduledEvent', () {
    test('has correct event name', () {
      final event = NotificationsScheduledEvent(
        pactId: 'pact-1',
        notificationsCount: 5,
        reminderOffsetMinutes: 10,
      );

      expect(event.name, equals('notifications_scheduled'));
    });

    test('toParameters includes all expected keys', () {
      final event = NotificationsScheduledEvent(
        pactId: 'pact-1',
        notificationsCount: 5,
        reminderOffsetMinutes: 10,
      );

      final params = event.toParameters();
      expect(params['pact_id'], equals('pact-1'));
      expect(params['notifications_count'], equals(5));
      expect(params['reminder_offset_minutes'], equals(10));
    });
  });

  group('AppOpenedFromNotificationEvent', () {
    test('has correct event name', () {
      final event = AppOpenedFromNotificationEvent(
        pactId: 'pact-1',
        showupId: 'showup-1',
        coldStart: true,
      );

      expect(event.name, equals('app_opened_from_notification'));
    });

    test('toParameters includes pact_id, showup_id, and cold_start', () {
      final event = AppOpenedFromNotificationEvent(
        pactId: 'pact-abc',
        showupId: 'showup-xyz',
        coldStart: false,
      );

      final params = event.toParameters();
      expect(params['pact_id'], equals('pact-abc'));
      expect(params['showup_id'], equals('showup-xyz'));
      expect(params['cold_start'], equals(false));
    });

    test('toParameters sets cold_start true for cold start', () {
      final event = AppOpenedFromNotificationEvent(
        pactId: 'pact-1',
        showupId: 'showup-1',
        coldStart: true,
      );

      final params = event.toParameters();
      expect(params['cold_start'], isTrue);
    });
  });
}
