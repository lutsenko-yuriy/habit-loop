import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

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
}
