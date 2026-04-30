import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

// 2054 has the same weekday structure as 2026 (28-year Gregorian cycle),
// and is far enough in the future that DateTime.now() filtering won't affect these tests.
Pact _pact({
  required ShowupSchedule schedule,
  DateTime? startDate,
  DateTime? endDate,
  Duration? reminderOffset,
}) {
  return Pact(
    id: 'pact-1',
    habitName: 'Meditate',
    startDate: startDate ?? DateTime(2054, 4, 1),
    endDate: endDate ?? DateTime(2054, 4, 30),
    showupDuration: const Duration(minutes: 10),
    schedule: schedule,
    status: PactStatus.active,
    reminderOffset: reminderOffset,
  );
}

void main() {
  group('ShowupGenerator', () {
    group('DailySchedule', () {
      test('generates one showup per day within the pact range', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 3),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 3);
        expect(showups[0].scheduledAt, DateTime(2054, 4, 1, 7, 0));
        expect(showups[1].scheduledAt, DateTime(2054, 4, 2, 7, 0));
        expect(showups[2].scheduledAt, DateTime(2054, 4, 3, 7, 0));
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
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 1),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.first.pactId, 'pact-1');
        expect(showups.first.duration, const Duration(minutes: 10));
      });

      test('each showup has a unique id', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 5),
        );

        final showups = ShowupGenerator.generate(pact);
        final ids = showups.map((s) => s.id).toSet();

        expect(ids.length, showups.length);
      });

      test('handles time with minutes', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7, minutes: 30)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 1),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.first.scheduledAt, DateTime(2054, 4, 1, 7, 30));
      });
    });

    group('WeekdaySchedule', () {
      test('generates showups only on specified weekdays', () {
        // April 2054 (same weekday structure as April 2026): Mon=6,13,20,27 / Wed=1,8,15,22,29
        final pact = _pact(
          schedule: const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 6)),
            WeekdayEntry(weekday: DateTime.wednesday, timeOfDay: Duration(hours: 18)),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 14),
        );

        final showups = ShowupGenerator.generate(pact);

        // April 1=Wed, 6=Mon, 8=Wed, 13=Mon
        expect(showups.length, 4);
        expect(showups[0].scheduledAt, DateTime(2054, 4, 1, 18, 0)); // Wed
        expect(showups[1].scheduledAt, DateTime(2054, 4, 6, 6, 0)); // Mon
        expect(showups[2].scheduledAt, DateTime(2054, 4, 8, 18, 0)); // Wed
        expect(showups[3].scheduledAt, DateTime(2054, 4, 13, 6, 0)); // Mon
      });

      test('generates nothing if no weekday matches the range', () {
        // Only Sunday, but range is Mon-Fri (April 6-10, 2054)
        final pact = _pact(
          schedule: const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.sunday, timeOfDay: Duration(hours: 9)),
          ]),
          startDate: DateTime(2054, 4, 6),
          endDate: DateTime(2054, 4, 10),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups, isEmpty);
      });
    });

    group('MonthlyByWeekdaySchedule', () {
      test('generates showup on correct occurrence of weekday each month', () {
        // 2nd Monday of April 2054 = April 13
        // 2nd Monday of May 2054 = May 11
        final pact = _pact(
          schedule: const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(
              occurrence: 2,
              weekday: DateTime.monday,
              timeOfDay: Duration(hours: 9),
            ),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2054, 4, 13, 9, 0));
        expect(showups[1].scheduledAt, DateTime(2054, 5, 11, 9, 0));
      });

      test('skips month if occurrence does not exist', () {
        // 5th Monday of April 2054 does not exist (only 4 Mondays: 6,13,20,27)
        // 5th Monday of June 2054 = June 29
        final pact = _pact(
          schedule: const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(
              occurrence: 5,
              weekday: DateTime.monday,
              timeOfDay: Duration(hours: 9),
            ),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 6, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        // April: no 5th Monday. May: May 4,11,18,25 — no 5th. June: Jun 1,8,15,22,29 — 5th Monday = Jun 29
        expect(showups.length, 1);
        expect(showups[0].scheduledAt, DateTime(2054, 6, 29, 9, 0));
      });
    });

    group('MonthlyByDateSchedule', () {
      test('generates showup on specified day of each month', () {
        // 15th of April and May 2054
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2054, 4, 15, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2054, 5, 15, 8, 0));
      });

      test('skips months where the day does not exist', () {
        // Day 31 does not exist in April (30 days) or June (30 days)
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 31, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2054, 3, 1),
          endDate: DateTime(2054, 6, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        // March 31 and May 31 exist; April 31 and June 31 do not
        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2054, 3, 31, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2054, 5, 31, 8, 0));
      });

      test('skips day if it falls outside the pact date range', () {
        // Day 25, but pact starts April 26
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 25, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2054, 4, 26),
          endDate: DateTime(2054, 5, 31),
        );

        final showups = ShowupGenerator.generate(pact);

        // April 25 is before the start; May 25 is within range
        expect(showups.length, 1);
        expect(showups[0].scheduledAt, DateTime(2054, 5, 25, 8, 0));
      });

      test('multiple entries per month generates multiple showups', () {
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 20)),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].scheduledAt, DateTime(2054, 4, 1, 8, 0));
        expect(showups[1].scheduledAt, DateTime(2054, 4, 15, 20, 0));
      });

      test('two entries at the same datetime produce unique ids', () {
        // Edge case: two entries resolving to the same day+time
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
            MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 30),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 2);
        expect(showups[0].id, isNot(equals(showups[1].id)));
      });
    });

    group('cutoff filtering', () {
      test('skips showup when scheduledAt - reminderOffset is already past', () {
        // scheduledAt = 10 days from now, reminderOffset = 20 days
        // → cutoff = 10 days ago (past) → filtered
        final now = DateTime.now();
        final pact = _pact(
          schedule: DailySchedule(timeOfDay: Duration(hours: now.hour)),
          startDate: DateTime(now.year, now.month, now.day + 10),
          endDate: DateTime(now.year, now.month, now.day + 10),
          reminderOffset: const Duration(days: 20),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups, isEmpty);
      });

      test('includes showup when scheduledAt - reminderOffset is in the future', () {
        // scheduledAt = 30 days from now, reminderOffset = 5 days
        // → cutoff = 25 days from now (future) → included
        final now = DateTime.now();
        final pact = _pact(
          schedule: DailySchedule(timeOfDay: Duration(hours: now.hour)),
          startDate: DateTime(now.year, now.month, now.day + 30),
          endDate: DateTime(now.year, now.month, now.day + 30),
          reminderOffset: const Duration(days: 5),
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups.length, 1);
      });

      test('skips showup with no reminder when scheduledAt is in the past', () {
        // No reminderOffset → cutoff = scheduledAt itself → past showups filtered
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: yesterday,
          endDate: yesterday,
        );

        final showups = ShowupGenerator.generate(pact);

        expect(showups, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // generateWindow tests
    // -------------------------------------------------------------------------

    group('generateWindow', () {
      group('DailySchedule', () {
        test('returns only showups within the given window', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          // Request just April 5–7
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 5),
            to: DateTime(2054, 4, 7),
          );

          expect(showups.length, 3);
          expect(showups[0].scheduledAt, DateTime(2054, 4, 5, 7, 0));
          expect(showups[1].scheduledAt, DateTime(2054, 4, 6, 7, 0));
          expect(showups[2].scheduledAt, DateTime(2054, 4, 7, 7, 0));
        });

        test('window clamped to pact boundaries — window starts before pact', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 5),
            endDate: DateTime(2054, 4, 10),
          );

          // Window starts before pact start
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 1),
            to: DateTime(2054, 4, 7),
          );

          // Should only produce April 5, 6, 7
          expect(showups.length, 3);
          expect(showups.first.scheduledAt, DateTime(2054, 4, 5, 8, 0));
        });

        test('window clamped to pact boundaries — window ends after pact', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 5),
            endDate: DateTime(2054, 4, 10),
          );

          // Window extends past pact end
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 8),
            to: DateTime(2054, 4, 15),
          );

          // Should only produce April 8, 9, 10
          expect(showups.length, 3);
          expect(showups.last.scheduledAt, DateTime(2054, 4, 10, 8, 0));
        });

        test('returns empty list when window is entirely outside pact range', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 5, 1),
            to: DateTime(2054, 5, 10),
          );

          expect(showups, isEmpty);
        });

        test('all generated showups are pending', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 1),
            to: DateTime(2054, 4, 3),
          );

          expect(showups.every((s) => s.status == ShowupStatus.pending), isTrue);
        });

        test('IDs are deterministic — regenerating the same window yields same IDs', () {
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          final first = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 5),
            to: DateTime(2054, 4, 8),
          );
          final second = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 5),
            to: DateTime(2054, 4, 8),
          );

          expect(first.map((s) => s.id).toList(), equals(second.map((s) => s.id).toList()));
        });

        test('IDs from overlapping windows are consistent with full generate()', () {
          // generateWindow IDs for a given date must match what generate() produces
          // for the same date (so we can safely deduplicate by ID in the service).
          final pact = _pact(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 5),
          );

          final full = ShowupGenerator.generate(pact);
          final window = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 2),
            to: DateTime(2054, 4, 4),
          );

          // The IDs in the window must be a subset of IDs from the full generation.
          final fullIds = full.map((s) => s.id).toSet();
          for (final s in window) {
            expect(fullIds, contains(s.id));
          }
        });
      });

      group('WeekdaySchedule', () {
        test('returns only showups on matching weekdays within window', () {
          // April 2054: Mon=6,13,20,27 / Wed=1,8,15,22,29
          final pact = _pact(
            schedule: const WeekdaySchedule(entries: [
              WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 6)),
              WeekdayEntry(weekday: DateTime.wednesday, timeOfDay: Duration(hours: 18)),
            ]),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          // Window: April 5–10 → Mon Apr 6, Wed Apr 8
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 5),
            to: DateTime(2054, 4, 10),
          );

          expect(showups.length, 2);
          expect(showups[0].scheduledAt, DateTime(2054, 4, 6, 6, 0));
          expect(showups[1].scheduledAt, DateTime(2054, 4, 8, 18, 0));
        });

        test('returns empty list when window contains no matching weekday', () {
          // Only Sunday, window covers Mon–Fri
          final pact = _pact(
            schedule: const WeekdaySchedule(entries: [
              WeekdayEntry(weekday: DateTime.sunday, timeOfDay: Duration(hours: 9)),
            ]),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 4, 30),
          );

          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 7),
            to: DateTime(2054, 4, 11),
          );

          expect(showups, isEmpty);
        });
      });

      group('MonthlyByWeekdaySchedule', () {
        test('returns matching monthly occurrences within window', () {
          // 2nd Monday of April 2054 = April 13; 2nd Monday of May 2054 = May 11
          final pact = _pact(
            schedule: const MonthlyByWeekdaySchedule(entries: [
              MonthlyWeekdayEntry(
                occurrence: 2,
                weekday: DateTime.monday,
                timeOfDay: Duration(hours: 9),
              ),
            ]),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 5, 31),
          );

          // Window covers only April 10–15 → only April 13
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 10),
            to: DateTime(2054, 4, 15),
          );

          expect(showups.length, 1);
          expect(showups[0].scheduledAt, DateTime(2054, 4, 13, 9, 0));
        });
      });

      group('MonthlyByDateSchedule', () {
        test('returns matching monthly-date showups within window', () {
          // 15th of April and May 2054
          final pact = _pact(
            schedule: const MonthlyByDateSchedule(entries: [
              MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 8)),
            ]),
            startDate: DateTime(2054, 4, 1),
            endDate: DateTime(2054, 5, 31),
          );

          // Window: April 14–16 → only April 15
          final showups = ShowupGenerator.generateWindow(
            pact,
            from: DateTime(2054, 4, 14),
            to: DateTime(2054, 4, 16),
          );

          expect(showups.length, 1);
          expect(showups[0].scheduledAt, DateTime(2054, 4, 15, 8, 0));
        });
      });
    });

    // -------------------------------------------------------------------------
    // countTotal tests
    // -------------------------------------------------------------------------

    group('countTotal', () {
      test('equals the number of showups generate() produces for daily schedule', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 30),
        );

        final count = ShowupGenerator.countTotal(pact);
        final generated = ShowupGenerator.generate(pact);

        expect(count, generated.length);
      });

      test('equals the number of showups generate() produces for weekday schedule', () {
        // Mon + Wed, April 2054 (30 days): 4 Mondays + 5 Wednesdays = 9 total
        final pact = _pact(
          schedule: const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 6)),
            WeekdayEntry(weekday: DateTime.wednesday, timeOfDay: Duration(hours: 18)),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 30),
        );

        final count = ShowupGenerator.countTotal(pact);
        final generated = ShowupGenerator.generate(pact);

        expect(count, generated.length);
      });

      test('equals the number of showups generate() produces for monthly-by-weekday', () {
        final pact = _pact(
          schedule: const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(
              occurrence: 2,
              weekday: DateTime.monday,
              timeOfDay: Duration(hours: 9),
            ),
          ]),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 5, 31),
        );

        final count = ShowupGenerator.countTotal(pact);
        final generated = ShowupGenerator.generate(pact);

        expect(count, generated.length);
      });

      test('equals the number of showups generate() produces for monthly-by-date', () {
        final pact = _pact(
          schedule: const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 31, timeOfDay: Duration(hours: 8)),
          ]),
          startDate: DateTime(2054, 3, 1),
          endDate: DateTime(2054, 6, 30),
        );

        final count = ShowupGenerator.countTotal(pact);
        final generated = ShowupGenerator.generate(pact);

        // March 31 + May 31 = 2 (April and June have no 31st)
        expect(count, 2);
        expect(count, generated.length);
      });

      test('returns zero for a pact with an empty date range', () {
        // endDate before startDate — degenerate case
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2054, 4, 10),
          endDate: DateTime(2054, 4, 5),
        );

        final count = ShowupGenerator.countTotal(pact);

        expect(count, 0);
      });

      test('countTotal equals generateWindow across the full pact range', () {
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 30),
        );

        final count = ShowupGenerator.countTotal(pact);
        final windowShowups = ShowupGenerator.generateWindow(
          pact,
          from: pact.startDate,
          to: pact.endDate,
        );

        expect(count, windowShowups.length);
      });

      test('countTotal is not affected by reminderOffset (counts all scheduled slots)', () {
        // countTotal should count all schedule slots regardless of reminder cutoff.
        // This is important so PactStats can display total even when generate()
        // skips past showups.
        final pact = _pact(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 3),
          reminderOffset: const Duration(days: 999), // would filter all in generate()
        );

        final count = ShowupGenerator.countTotal(pact);

        // All 3 days must be counted even though generate() would skip them
        expect(count, 3);
      });

      test('countTotal respects createdAt — excludes slots before pact was created', () {
        // A pact starting Apr 1 but created at 22:00 on Apr 1 must not count
        // the 08:00 slot that was never reachable.
        final pact = Pact(
          id: 'pact-1',
          habitName: 'Meditate',
          startDate: DateTime(2054, 4, 1),
          endDate: DateTime(2054, 4, 3), // 3-day pact: Apr 1, 2, 3
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          createdAt: DateTime(2054, 4, 1, 22, 0), // created at 22:00 on Apr 1
        );

        final count = ShowupGenerator.countTotal(pact);

        // Apr 1 08:00 is before createdAt (22:00) → excluded.
        // Apr 2 08:00 and Apr 3 08:00 → included. Total = 2.
        expect(count, 2);
      });
    });
  });
}
