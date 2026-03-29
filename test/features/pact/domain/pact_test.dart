import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

void main() {
  group('Pact', () {
    test('creates an active pact with required fields', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      expect(pact.id, '1');
      expect(pact.habitName, 'Meditate');
      expect(pact.startDate, DateTime(2026, 3, 29));
      expect(pact.endDate, DateTime(2026, 9, 29));
      expect(pact.showupDuration, const Duration(minutes: 10));
      expect(pact.schedule, isA<DailySchedule>());
      expect(pact.status, PactStatus.active);
      expect(pact.reminderOffset, isNull);
      expect(pact.stopReason, isNull);
    });

    test('creates a pact with optional reminder offset', () {
      final pact = Pact(
        id: '2',
        habitName: 'Jog',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 10, 1),
        showupDuration: const Duration(minutes: 30),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 6)),
        status: PactStatus.active,
        reminderOffset: const Duration(minutes: 15),
      );

      expect(pact.reminderOffset, const Duration(minutes: 15));
    });

    test('stopped pact can have a stop reason', () {
      final pact = Pact(
        id: '3',
        habitName: 'Read',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 1),
        showupDuration: const Duration(minutes: 20),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 21)),
        status: PactStatus.stopped,
        stopReason: 'Not enough time in my schedule',
      );

      expect(pact.status, PactStatus.stopped);
      expect(pact.stopReason, 'Not enough time in my schedule');
    });

    test('two pacts with same fields are equal', () {
      final a = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final b = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PactStatus', () {
    test('has three values', () {
      expect(PactStatus.values, hasLength(3));
      expect(PactStatus.values, contains(PactStatus.active));
      expect(PactStatus.values, contains(PactStatus.stopped));
      expect(PactStatus.values, contains(PactStatus.completed));
    });
  });
}
