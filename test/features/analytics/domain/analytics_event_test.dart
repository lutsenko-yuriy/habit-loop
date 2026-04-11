import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/analytics/domain/analytics_event.dart';

void main() {
  group('PactCreatedEvent', () {
    test('has correct name', () {
      final event = PactCreatedEvent(
        scheduleType: 'daily',
        durationDays: 180,
        showupDurationMinutes: 10,
        showupsExpected: 180,
      );
      expect(event.name, 'pact_created');
    });

    test('toParameters includes all non-null properties', () {
      final event = PactCreatedEvent(
        scheduleType: 'weekly',
        durationDays: 90,
        showupDurationMinutes: 30,
        reminderOffsetMinutes: 15,
        showupsExpected: 52,
      );
      final params = event.toParameters();
      expect(params['schedule_type'], 'weekly');
      expect(params['duration_days'], 90);
      expect(params['showup_duration_minutes'], 30);
      expect(params['reminder_offset_minutes'], 15);
      expect(params['showups_expected'], 52);
    });

    test('toParameters omits null reminder_offset_minutes', () {
      final event = PactCreatedEvent(
        scheduleType: 'monthly',
        durationDays: 180,
        showupDurationMinutes: 20,
        showupsExpected: 24,
      );
      final params = event.toParameters();
      expect(params.containsKey('reminder_offset_minutes'), isFalse);
    });

    test('toParameters does not contain null values', () {
      final event = PactCreatedEvent(
        scheduleType: 'daily',
        durationDays: 180,
        showupDurationMinutes: 10,
        showupsExpected: 180,
      );
      final params = event.toParameters();
      expect(params.values.whereType<Null>(), isEmpty);
    });
  });

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

  group('PactStoppedEvent', () {
    test('has correct name', () {
      final event = PactStoppedEvent(
        daysActive: 30,
        totalShowupsDone: 25,
        totalShowupsFailed: 3,
        totalShowupsRemaining: 2,
      );
      expect(event.name, 'pact_stopped');
    });

    test('toParameters includes all properties', () {
      final event = PactStoppedEvent(
        daysActive: 30,
        totalShowupsDone: 25,
        totalShowupsFailed: 3,
        totalShowupsRemaining: 2,
      );
      final params = event.toParameters();
      expect(params['days_active'], 30);
      expect(params['total_showups_done'], 25);
      expect(params['total_showups_failed'], 3);
      expect(params['total_showups_remaining'], 2);
    });
  });
}
