import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

Pact _pact({
  required ShowupSchedule schedule,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return Pact(
    id: 'pact-1',
    habitName: 'Meditate',
    startDate: startDate ?? DateTime(2026, 4, 1),
    endDate: endDate ?? DateTime(2026, 4, 30),
    showupDuration: const Duration(minutes: 10),
    schedule: schedule,
    status: PactStatus.active,
  );
}

void main() {
  group('ShowupGenerator', () {
    group('DailySchedule', () {
      test('generates one showup per day within the pact range', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 3),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 3);
        expect(showups[0].scheduledAt, DateTime(2026, 4, 1, 7, 0));
        expect(showups[1].scheduledAt, DateTime(2026, 4, 2, 7, 0));
        expect(showups[2].scheduledAt, DateTime(2026, 4, 3, 7, 0));
      });

      test('all generated showups are pending', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.every((s) => s.status == ShowupStatus.pending), isTrue);
      });

      test('generated showups have correct pactId and duration', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 1),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.first.pactId, 'pact-1');
        expect(showups.first.duration, const Duration(minutes: 10));
      });

      test('each showup has a unique id', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 5),
        );

        final showups = ShowupGenerator.generate(pact);
        final ids = showups.map((s) => s.id).toSet();

        expect(ids.length, showups.length);
      });

      test('handles time with minutes', () {
        final pact = _pact(
          schedule:
              const DailySchedule(timeOfDay: Duration(hours: 7, minutes: 30)),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 1),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.first.scheduledAt, DateTime(2026, 4, 1, 7, 30));
      });
    });

    group('WeekdaySchedule', () {
      test('generates showups only on specified weekdays', () {
        // April 2026: Mon=6,13,20,27 / Wed=1,8,15,22,29
        final pact = _pact(
          schedule: const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 6)),
            WeekdayEntry(
                weekday: DateTime.wednesday, timeOfDay: Duration(hours: 18)),
          ]),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 14),
        );

        final showups = ShowupGenerator.generate(pact);

        // April 1=Wed, 6=Mon, 8=Wed, 13=Mon
        expect(showups.length, 4);
        expect(showups[0].scheduledAt, DateTime(2026, 4, 1, 18, 0)); // Wed
        expect(showups[1].scheduledAt, DateTime(2026, 4, 6, 6, 0));  // Mon
        expect(showups[2].scheduledAt, DateTime(2026, 4, 8, 18, 0)); // Wed
        expect(showups[3].scheduledAt, DateTime(2026, 4, 13, 6, 0)); // Mon
      });

      test('generates nothing if no weekday matches the range', () {
        // Only Sunday, but range is Mon-Fri (April 6-10, 2026)
        final pact = _pact(
          schedule: const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.sunday, timeOfDay: Duration(hours: 9)),
          ]),
          startDate: DateTime(2026, 4, 6),
          endDate: DateTime(2026, 4, 10),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups, isEmpty);
      });
    });

    group('MonthlyByWeekdaySchedule', () {
      test('generates showup on correct occurrence of weekday each month', () {
        // 2nd Monday of April 2026 = April 13
        // 2nd Monday of May 2026 = May 11
        final pact = _pact(
          schedule: const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(
              occurrence: 2,
              weekday: DateTime.monday,
              timeOfDay: Duration(hours: 9),
            ),
          ]),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2026, 4, 13, 9, 0));
        expect(showups[1].scheduledAt, DateTime(2026, 5, 11, 9, 0));
      });

      test('skips month if occurrence does not exist', () {
        // 5th Monday of April 2026 does not exist (only 4 Mondays: 6,13,20,27)
        // 5th Monday of June 2026 = June 29
        final pact = _pact(
          schedule: const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(
              occurrence: 5,
              weekday: DateTime.monday,
              timeOfDay: Duration(hours: 9),
            ),
          ]),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 6, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        // April: no 5th Monday. May: May 4,11,18,25 — no 5th. June: Jun 1,8,15,22,29 — 5th Monday = Jun 29
        expect(showups.length, 1);
        expect(showups[0].scheduledAt, DateTime(2026, 6, 29, 9, 0));
      });
    });

    group('MonthlyByDateSchedule', () {
      test('generates showup on specified day of each month', () {
        // 15th of April and May 2026
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2026, 4, 15, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2026, 5, 15, 8, 0));
      });

      test('skips months where the day does not exist', () {
        // Day 31 does not exist in April (30 days) or June (30 days)
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 31, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 6, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        // March 31 and May 31 exist; April 31 and June 31 do not
        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2026, 3, 31, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2026, 5, 31, 8, 0));
      });

      test('skips day if it falls outside the pact date range', () {
        // Day 25, but pact starts April 26
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 25, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2026, 4, 26),
          endDate: DateTime(2026, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        // April 25 is before the start; May 25 is within range
        expect(showups.length, 1);
        expect(showups[0].scheduledAt, DateTime(2026, 5, 25, 8, 0));
      });

      test('multiple entries per month generates multiple showups', () {
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 20)),
          ]),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2026, 4, 1, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2026, 4, 15, 20, 0));
      });
    });
  });
}
