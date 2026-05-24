import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';

void main() {
  group('DailySchedule', () {
    test('stores time of day', () {
      const schedule = DailySchedule(timeOfDay: Duration(hours: 7, minutes: 30));

      expect(schedule.timeOfDay, const Duration(hours: 7, minutes: 30));
    });

    test('equality', () {
      const a = DailySchedule(timeOfDay: Duration(hours: 7));
      const b = DailySchedule(timeOfDay: Duration(hours: 7));
      const c = DailySchedule(timeOfDay: Duration(hours: 8));

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('WeekdaySchedule', () {
    test('stores weekday-time pairs', () {
      const schedule = WeekdaySchedule(entries: [
        WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
        WeekdayEntry(weekday: DateTime.saturday, timeOfDay: Duration(hours: 16)),
      ]);

      expect(schedule.entries, hasLength(2));
      expect(schedule.entries[0].weekday, DateTime.monday);
      expect(schedule.entries[0].timeOfDay, const Duration(hours: 7));
      expect(schedule.entries[1].weekday, DateTime.saturday);
    });

    test('equality', () {
      const a = WeekdaySchedule(entries: [
        WeekdayEntry(weekday: DateTime.tuesday, timeOfDay: Duration(hours: 19)),
      ]);
      const b = WeekdaySchedule(entries: [
        WeekdayEntry(weekday: DateTime.tuesday, timeOfDay: Duration(hours: 19)),
      ]);

      expect(a, equals(b));
    });
  });

  group('MonthlyByWeekdaySchedule', () {
    test('stores occurrence and weekday', () {
      const schedule = MonthlyByWeekdaySchedule(entries: [
        MonthlyWeekdayEntry(
          occurrence: 2,
          weekday: DateTime.tuesday,
          timeOfDay: Duration(hours: 10),
        ),
      ]);

      expect(schedule.entries[0].occurrence, 2);
      expect(schedule.entries[0].weekday, DateTime.tuesday);
      expect(schedule.entries[0].timeOfDay, const Duration(hours: 10));
    });
  });

  group('MonthlyByDateSchedule', () {
    test('stores day of month', () {
      const schedule = MonthlyByDateSchedule(entries: [
        MonthlyDateEntry(dayOfMonth: 25, timeOfDay: Duration(hours: 14)),
      ]);

      expect(schedule.entries[0].dayOfMonth, 25);
      expect(schedule.entries[0].timeOfDay, const Duration(hours: 14));
    });
  });

  group('WeeklySlot', () {
    test('stores weekdays and timeOfDay', () {
      final slot = WeeklySlot(
        weekdays: {DateTime.monday, DateTime.wednesday},
        timeOfDay: const Duration(hours: 8),
      );

      expect(slot.weekdays, containsAll([DateTime.monday, DateTime.wednesday]));
      expect(slot.timeOfDay, const Duration(hours: 8));
    });

    test('equality — same weekdays (any insertion order) and same time are equal', () {
      final a = WeeklySlot(weekdays: {1, 3, 5}, timeOfDay: const Duration(hours: 8));
      final b = WeeklySlot(weekdays: {5, 1, 3}, timeOfDay: const Duration(hours: 8));

      expect(a, equals(b));
    });

    test('equality — different time means not equal', () {
      final a = WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8));
      final b = WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 9));

      expect(a, isNot(equals(b)));
    });

    test('equality — different weekdays means not equal', () {
      final a = WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8));
      final b = WeeklySlot(weekdays: {2}, timeOfDay: const Duration(hours: 8));

      expect(a, isNot(equals(b)));
    });

    test('equality — extra weekday means not equal', () {
      final a = WeeklySlot(weekdays: {1, 3}, timeOfDay: const Duration(hours: 8));
      final b = WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8));

      expect(a, isNot(equals(b)));
    });

    test('hashCode is stable regardless of weekday insertion order', () {
      final a = WeeklySlot(weekdays: {1, 3, 5}, timeOfDay: const Duration(hours: 8));
      final b = WeeklySlot(weekdays: {5, 1, 3}, timeOfDay: const Duration(hours: 8));

      expect(a.hashCode, equals(b.hashCode));
    });

    test('is a ScheduleSlot', () {
      final slot = WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8));
      expect(slot, isA<ScheduleSlot>());
    });
  });

  group('MonthlySlot', () {
    test('stores dayOfMonth and timeOfDay', () {
      const slot = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9));

      expect(slot.dayOfMonth, 15);
      expect(slot.timeOfDay, const Duration(hours: 9));
    });

    test('equality — same day and time are equal', () {
      const a = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9));
      const b = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9));

      expect(a, equals(b));
    });

    test('equality — different day means not equal', () {
      const a = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9));
      const c = MonthlySlot(dayOfMonth: 16, timeOfDay: Duration(hours: 9));

      expect(a, isNot(equals(c)));
    });

    test('equality — different time means not equal', () {
      const a = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9));
      const d = MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 10));

      expect(a, isNot(equals(d)));
    });

    test('is a ScheduleSlot', () {
      const slot = MonthlySlot(dayOfMonth: 1, timeOfDay: Duration(hours: 8));
      expect(slot, isA<ScheduleSlot>());
    });
  });

  group('SlotSchedule', () {
    test('stores a list of slots', () {
      final schedule = SlotSchedule(slots: [
        WeeklySlot(weekdays: {1, 3}, timeOfDay: const Duration(hours: 8)),
        const MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 9)),
      ]);

      expect(schedule.slots, hasLength(2));
    });

    test('equality — same slots in same order are equal', () {
      final a = SlotSchedule(slots: [
        WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
      ]);
      final b = SlotSchedule(slots: [
        WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
      ]);

      expect(a, equals(b));
    });

    test('equality — different slots means not equal', () {
      final a = SlotSchedule(slots: [
        WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
      ]);
      final b = SlotSchedule(slots: [
        WeeklySlot(weekdays: {2}, timeOfDay: const Duration(hours: 8)),
      ]);

      expect(a, isNot(equals(b)));
    });

    test('empty slot list is valid and equal to another empty', () {
      expect(const SlotSchedule(slots: []), equals(const SlotSchedule(slots: [])));
    });

    test('is a ShowupSchedule', () {
      const schedule = SlotSchedule(slots: []);
      expect(schedule, isA<ShowupSchedule>());
    });
  });
}
