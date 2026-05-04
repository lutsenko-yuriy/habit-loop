import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/persistence/schedule_codec.dart';

void main() {
  group('ScheduleCodec', () {
    group('DailySchedule', () {
      test('round-trips a simple daily schedule', () {
        const schedule = DailySchedule(timeOfDay: Duration(hours: 7, minutes: 30));
        final encoded = ScheduleCodec.encode(schedule);
        final decoded = ScheduleCodec.decode(encoded);
        expect(decoded, equals(schedule));
      });

      test('round-trips midnight time', () {
        const schedule = DailySchedule(timeOfDay: Duration.zero);
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('round-trips end-of-day time', () {
        const schedule = DailySchedule(timeOfDay: Duration(hours: 23, minutes: 59, seconds: 59));
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('encoded JSON contains type discriminator "daily"', () {
        const schedule = DailySchedule(timeOfDay: Duration(hours: 8));
        final encoded = ScheduleCodec.encode(schedule);
        expect(encoded, contains('"type":"daily"'));
      });
    });

    group('WeekdaySchedule', () {
      test('round-trips a single-entry weekday schedule', () {
        const schedule = WeekdaySchedule(
          entries: [WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7))],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('round-trips multiple entries', () {
        const schedule = WeekdaySchedule(
          entries: [
            WeekdayEntry(weekday: DateTime.tuesday, timeOfDay: Duration(hours: 19)),
            WeekdayEntry(weekday: DateTime.saturday, timeOfDay: Duration(hours: 16)),
          ],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('round-trips empty entries list', () {
        const schedule = WeekdaySchedule(entries: []);
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('encoded JSON contains type discriminator "weekday"', () {
        const schedule = WeekdaySchedule(
          entries: [WeekdayEntry(weekday: DateTime.friday, timeOfDay: Duration(hours: 9))],
        );
        final encoded = ScheduleCodec.encode(schedule);
        expect(encoded, contains('"type":"weekday"'));
      });
    });

    group('MonthlyByWeekdaySchedule', () {
      test('round-trips a single-entry monthly-by-weekday schedule', () {
        const schedule = MonthlyByWeekdaySchedule(
          entries: [MonthlyWeekdayEntry(occurrence: 2, weekday: DateTime.tuesday, timeOfDay: Duration(hours: 10))],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('round-trips multiple entries', () {
        const schedule = MonthlyByWeekdaySchedule(
          entries: [
            MonthlyWeekdayEntry(occurrence: 1, weekday: DateTime.monday, timeOfDay: Duration(hours: 8)),
            MonthlyWeekdayEntry(occurrence: 3, weekday: DateTime.friday, timeOfDay: Duration(hours: 17, minutes: 30)),
          ],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('encoded JSON contains type discriminator "monthlyByWeekday"', () {
        const schedule = MonthlyByWeekdaySchedule(
          entries: [MonthlyWeekdayEntry(occurrence: 1, weekday: DateTime.wednesday, timeOfDay: Duration(hours: 12))],
        );
        final encoded = ScheduleCodec.encode(schedule);
        expect(encoded, contains('"type":"monthlyByWeekday"'));
      });
    });

    group('MonthlyByDateSchedule', () {
      test('round-trips a single-entry monthly-by-date schedule', () {
        const schedule = MonthlyByDateSchedule(
          entries: [MonthlyDateEntry(dayOfMonth: 25, timeOfDay: Duration(hours: 9))],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('round-trips multiple entries', () {
        const schedule = MonthlyByDateSchedule(
          entries: [
            MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 6)),
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 18, minutes: 45)),
          ],
        );
        final decoded = ScheduleCodec.decode(ScheduleCodec.encode(schedule));
        expect(decoded, equals(schedule));
      });

      test('encoded JSON contains type discriminator "monthlyByDate"', () {
        const schedule = MonthlyByDateSchedule(
          entries: [MonthlyDateEntry(dayOfMonth: 10, timeOfDay: Duration(hours: 10))],
        );
        final encoded = ScheduleCodec.encode(schedule);
        expect(encoded, contains('"type":"monthlyByDate"'));
      });
    });

    group('decode', () {
      test('throws ArgumentError for unknown type', () {
        expect(
          () => ScheduleCodec.decode('{"type":"unknown"}'),
          throwsArgumentError,
        );
      });

      test('throws FormatException for invalid JSON', () {
        expect(
          () => ScheduleCodec.decode('not-json'),
          throwsFormatException,
        );
      });

      test('throws FormatException when JSON root is a string, not an object', () {
        // Regression: jsonDecode('"daily"') succeeds but returns a String, not a
        // Map. Without a type guard the subsequent `as Map<String, dynamic>` cast
        // would throw TypeError instead of FormatException, masking the real error.
        expect(
          () => ScheduleCodec.decode('"daily"'),
          throwsFormatException,
        );
      });

      test('throws FormatException when JSON root is a number', () {
        expect(
          () => ScheduleCodec.decode('42'),
          throwsFormatException,
        );
      });

      test('throws FormatException when JSON root is an array', () {
        expect(
          () => ScheduleCodec.decode('[]'),
          throwsFormatException,
        );
      });
    });
  });
}
