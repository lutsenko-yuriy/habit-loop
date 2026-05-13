import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';

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

  group('dirty / syncedAt sync fields', () {
    test('dirty defaults to true when not specified', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      expect(pact.dirty, isTrue);
    });

    test('syncedAt defaults to null when not specified', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      expect(pact.syncedAt, isNull);
    });

    test('dirty can be set to false', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        dirty: false,
        syncedAt: DateTime(2026, 4, 1, 12, 0),
      );
      expect(pact.dirty, isFalse);
      expect(pact.syncedAt, equals(DateTime(2026, 4, 1, 12, 0)));
    });

    test('copyWith can mark pact as clean with a syncedAt timestamp', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final synced = pact.copyWith(dirty: false, syncedAt: DateTime(2026, 4, 1, 10, 0));
      expect(synced.dirty, isFalse);
      expect(synced.syncedAt, equals(DateTime(2026, 4, 1, 10, 0)));
      expect(synced.id, equals(pact.id));
    });

    test('copyWith can mark a clean pact dirty again', () {
      final pact = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        dirty: false,
        syncedAt: DateTime(2026, 4, 1),
      );
      final reDirtied = pact.copyWith(dirty: true);
      expect(reDirtied.dirty, isTrue);
    });

    test('two pacts differing only in dirty are not equal', () {
      final a = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        dirty: true,
      );
      final b = a.copyWith(dirty: false);
      expect(a, isNot(equals(b)));
    });

    test('two pacts differing only in syncedAt have different hashCodes', () {
      final a = Pact(
        id: '1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 29),
        endDate: DateTime(2026, 9, 29),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        dirty: false,
        syncedAt: DateTime(2026, 4, 1),
      );
      final b = a.copyWith(syncedAt: DateTime(2026, 4, 2));
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
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
