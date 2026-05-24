import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';

void main() {
  group('PactBuilder', () {
    group('defaults', () {
      test('startDate defaults to midnight of today', () {
        final today = DateTime(2026, 3, 30, 14, 30, 15); // with time component
        final builder = PactBuilder(today: today);
        expect(builder.startDate, DateTime(2026, 3, 30)); // midnight
        expect(builder.startDate.hour, 0);
        expect(builder.startDate.minute, 0);
        expect(builder.startDate.second, 0);
      });

      test('startDate defaults when today is already midnight', () {
        final today = DateTime(2026, 3, 30);
        final builder = PactBuilder(today: today);
        expect(builder.startDate, DateTime(2026, 3, 30));
      });

      test('endDate defaults to 6 months after today', () {
        final today = DateTime(2026, 3, 30);
        final builder = PactBuilder(today: today);
        expect(builder.endDate, DateTime(2026, 9, 30));
      });

      test('endDate clamps Aug 31 + 6 months to Feb 28', () {
        final builder = PactBuilder(today: DateTime(2026, 8, 31));
        expect(builder.endDate, DateTime(2027, 2, 28));
      });

      test('endDate clamps Mar 31 + 6 months to Sep 30', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 31));
        expect(builder.endDate, DateTime(2026, 9, 30));
      });

      test('endDate clamps Oct 31 + 6 months to Apr 30', () {
        final builder = PactBuilder(today: DateTime(2026, 10, 31));
        expect(builder.endDate, DateTime(2027, 4, 30));
      });

      test('endDate does not clamp Jan 31 + 6 months (Jul 31 exists)', () {
        final builder = PactBuilder(today: DateTime(2026, 1, 31));
        expect(builder.endDate, DateTime(2026, 7, 31));
      });

      test('habitName defaults to empty string', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 30));
        expect(builder.habitName, '');
      });

      test('showupDuration defaults to null', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 30));
        expect(builder.showupDuration, isNull);
      });

      test('scheduleType defaults to null', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 30));
        expect(builder.scheduleType, isNull);
      });

      test('schedule defaults to null', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 30));
        expect(builder.schedule, isNull);
      });

      test('reminderOffset defaults to null', () {
        final builder = PactBuilder(today: DateTime(2026, 3, 30));
        expect(builder.reminderOffset, isNull);
      });
    });

    group('isDateRangeValid', () {
      final today = DateTime(2026, 3, 30);

      test('returns true when startDate is before endDate', () {
        final builder = PactBuilder(today: today); // default is valid
        expect(builder.isDateRangeValid, isTrue);
      });

      test('returns false when startDate equals endDate', () {
        final builder = PactBuilder(today: today).copyWith(endDate: today);
        expect(builder.isDateRangeValid, isFalse);
      });

      test('returns false when startDate is after endDate', () {
        final builder = PactBuilder(today: today).copyWith(
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 3, 1),
        );
        expect(builder.isDateRangeValid, isFalse);
      });
    });

    group('isShowupDurationValid', () {
      final today = DateTime(2026, 3, 30);

      test('returns false when showupDuration is null', () {
        final builder = PactBuilder(today: today);
        expect(builder.isShowupDurationValid, isFalse);
      });

      test('returns false when showupDuration is 0 minutes', () {
        final builder = PactBuilder(today: today).copyWith(showupDuration: Duration.zero);
        expect(builder.isShowupDurationValid, isFalse);
      });

      test('returns true at lower boundary of 1 minute', () {
        final builder = PactBuilder(today: today).copyWith(
          showupDuration: const Duration(minutes: 1),
        );
        expect(builder.isShowupDurationValid, isTrue);
      });

      test('returns true at upper boundary of 120 minutes', () {
        final builder = PactBuilder(today: today).copyWith(
          showupDuration: const Duration(minutes: 120),
        );
        expect(builder.isShowupDurationValid, isTrue);
      });

      test('returns false above upper boundary at 121 minutes', () {
        final builder = PactBuilder(today: today).copyWith(
          showupDuration: const Duration(minutes: 121),
        );
        expect(builder.isShowupDurationValid, isFalse);
      });
    });

    group('isScheduleSet', () {
      final today = DateTime(2026, 3, 30);

      test('returns false when schedule is null', () {
        final builder = PactBuilder(today: today);
        expect(builder.isScheduleSet, isFalse);
      });

      test('returns true when schedule is set', () {
        final builder = PactBuilder(today: today).copyWith(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        );
        expect(builder.isScheduleSet, isTrue);
      });

      test('returns false for an empty SlotSchedule (no slots)', () {
        final builder = PactBuilder(today: today).copyWith(
          scheduleType: ScheduleType.slot,
          schedule: const SlotSchedule(slots: []),
        );
        expect(builder.isScheduleSet, isFalse);
      });

      test('returns true for a non-empty SlotSchedule', () {
        final builder = PactBuilder(today: today).copyWith(
          scheduleType: ScheduleType.slot,
          schedule: SlotSchedule(slots: [
            WeeklySlot(weekdays: {1, 2, 3}, timeOfDay: const Duration(hours: 8)),
          ]),
        );
        expect(builder.isScheduleSet, isTrue);
      });
    });

    group('isHabitNameValid', () {
      final today = DateTime(2026, 3, 30);

      test('returns false for empty string', () {
        final builder = PactBuilder(today: today); // defaults to ''
        expect(builder.isHabitNameValid, isFalse);
      });

      test('returns false for whitespace-only string', () {
        final builder = PactBuilder(today: today).copyWith(habitName: '   ');
        expect(builder.isHabitNameValid, isFalse);
      });

      test('returns true for non-empty string', () {
        final builder = PactBuilder(today: today).copyWith(habitName: 'Meditate');
        expect(builder.isHabitNameValid, isTrue);
      });

      test('returns true for string with leading/trailing whitespace but non-empty trim', () {
        final builder = PactBuilder(today: today).copyWith(habitName: '  Jog  ');
        expect(builder.isHabitNameValid, isTrue);
      });
    });

    group('isComplete', () {
      final today = DateTime(2026, 3, 30);

      PactBuilder completeBuilder() {
        return PactBuilder(today: today).copyWith(
          habitName: 'Meditate',
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        );
      }

      test('returns true when all predicates are satisfied', () {
        expect(completeBuilder().isComplete, isTrue);
      });

      test('returns false when habitName is invalid', () {
        final builder = completeBuilder().copyWith(habitName: '');
        expect(builder.isComplete, isFalse);
      });

      test('returns false when date range is invalid', () {
        final builder = completeBuilder().copyWith(
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 3, 1),
        );
        expect(builder.isComplete, isFalse);
      });

      test('returns false when showupDuration is invalid', () {
        final builder = completeBuilder().copyWith(showupDuration: Duration.zero);
        expect(builder.isComplete, isFalse);
      });

      test('returns false when schedule is not set', () {
        final builder = completeBuilder().copyWith(clearSchedule: true);
        expect(builder.isComplete, isFalse);
      });
    });

    group('build()', () {
      final today = DateTime(2026, 3, 30);

      PactBuilder completeBuilder() {
        return PactBuilder(today: today).copyWith(
          habitName: '  Meditate  ', // with leading/trailing spaces
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        );
      }

      test('returns Pact with status active', () {
        final pact = completeBuilder().build(id: 'test-id', createdAt: today);
        expect(pact.status, PactStatus.active);
      });

      test('trims habitName in the built Pact', () {
        final pact = completeBuilder().build(id: 'test-id', createdAt: today);
        expect(pact.habitName, 'Meditate');
      });

      test('injects the provided id', () {
        final pact = completeBuilder().build(id: 'my-pact-id', createdAt: today);
        expect(pact.id, 'my-pact-id');
      });

      test('injects the provided createdAt', () {
        final createdAt = DateTime(2026, 3, 30, 10, 0);
        final pact = completeBuilder().build(id: 'test-id', createdAt: createdAt);
        expect(pact.createdAt, createdAt);
      });

      test('copies all other fields correctly', () {
        const schedule = DailySchedule(timeOfDay: Duration(hours: 7));
        final builder = PactBuilder(today: today).copyWith(
          habitName: 'Jog',
          showupDuration: const Duration(minutes: 30),
          schedule: schedule,
          reminderOffset: const Duration(minutes: 15),
        );
        final pact = builder.build(id: 'p1', createdAt: today);
        expect(pact.startDate, builder.startDate);
        expect(pact.endDate, builder.endDate);
        expect(pact.showupDuration, const Duration(minutes: 30));
        expect(pact.schedule, schedule);
        expect(pact.reminderOffset, const Duration(minutes: 15));
      });

      test('throws StateError when isComplete is false', () {
        final incompleteBuilder = PactBuilder(today: today); // no name, no duration, no schedule
        expect(
          () => incompleteBuilder.build(id: 'test-id', createdAt: today),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('copyWith', () {
      final today = DateTime(2026, 3, 30);

      test('updates specified fields while preserving others', () {
        final original = PactBuilder(today: today);
        final updated = original.copyWith(habitName: 'Meditate');
        expect(updated.habitName, 'Meditate');
        expect(updated.startDate, original.startDate);
        expect(updated.endDate, original.endDate);
        expect(updated.showupDuration, isNull);
      });

      test('clearSchedule sets schedule to null', () {
        final builder = PactBuilder(today: today).copyWith(
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        );
        expect(builder.schedule, isNotNull);

        final cleared = builder.copyWith(clearSchedule: true);
        expect(cleared.schedule, isNull);
      });

      test('clearReminderOffset sets reminderOffset to null', () {
        final builder = PactBuilder(today: today).copyWith(
          reminderOffset: const Duration(minutes: 15),
        );
        expect(builder.reminderOffset, isNotNull);

        final cleared = builder.copyWith(clearReminderOffset: true);
        expect(cleared.reminderOffset, isNull);
      });

      test('clearSchedule false preserves existing schedule', () {
        const schedule = DailySchedule(timeOfDay: Duration(hours: 7));
        final builder = PactBuilder(today: today).copyWith(schedule: schedule);
        final updated = builder.copyWith(habitName: 'Jog'); // clearSchedule defaults to false
        expect(updated.schedule, schedule);
      });

      test('clearReminderOffset false preserves existing reminderOffset', () {
        const offset = Duration(minutes: 15);
        final builder = PactBuilder(today: today).copyWith(reminderOffset: offset);
        final updated = builder.copyWith(habitName: 'Jog'); // clearReminderOffset defaults to false
        expect(updated.reminderOffset, offset);
      });

      test('can update scheduleType independently', () {
        final builder = PactBuilder(today: today);
        final updated = builder.copyWith(scheduleType: ScheduleType.weekday);
        expect(updated.scheduleType, ScheduleType.weekday);
      });
    });

    group('fromPact — lazy migration to SlotSchedule', () {
      final today = DateTime(2026, 4, 1);

      Pact makePact(ShowupSchedule schedule) => Pact(
            id: 'p1',
            habitName: 'Run',
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 10, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: schedule,
            status: PactStatus.active,
          );

      test('DailySchedule → SlotSchedule with a single 7-day WeeklySlot', () {
        final builder = PactBuilder.fromPact(
          makePact(const DailySchedule(timeOfDay: Duration(hours: 7))),
          today: today,
        );

        expect(builder.scheduleType, ScheduleType.slot);
        final schedule = builder.schedule as SlotSchedule;
        expect(schedule.slots, hasLength(1));
        final slot = schedule.slots.first as WeeklySlot;
        expect(slot.weekdays.length, 7);
        expect(slot.weekdays, containsAll([1, 2, 3, 4, 5, 6, 7]));
        expect(slot.timeOfDay, const Duration(hours: 7));
      });

      test('WeekdaySchedule — entries with same time merge into one WeeklySlot', () {
        final builder = PactBuilder.fromPact(
          makePact(const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 8)),
            WeekdayEntry(weekday: DateTime.wednesday, timeOfDay: Duration(hours: 8)),
          ])),
          today: today,
        );

        final schedule = builder.schedule as SlotSchedule;
        expect(schedule.slots, hasLength(1));
        final slot = schedule.slots.first as WeeklySlot;
        expect(slot.weekdays, containsAll([DateTime.monday, DateTime.wednesday]));
        expect(slot.weekdays.length, 2);
        expect(slot.timeOfDay, const Duration(hours: 8));
      });

      test('WeekdaySchedule — entries with different times produce separate WeeklySlots', () {
        final builder = PactBuilder.fromPact(
          makePact(const WeekdaySchedule(entries: [
            WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 8)),
            WeekdayEntry(weekday: DateTime.saturday, timeOfDay: Duration(hours: 16)),
          ])),
          today: today,
        );

        final schedule = builder.schedule as SlotSchedule;
        expect(schedule.slots, hasLength(2));
        expect(schedule.slots.every((s) => s is WeeklySlot), isTrue);
        expect((schedule.slots[0] as WeeklySlot).timeOfDay, const Duration(hours: 8));
        expect((schedule.slots[1] as WeeklySlot).timeOfDay, const Duration(hours: 16));
      });

      test('MonthlyByDateSchedule → SlotSchedule with MonthlySlots preserving day and time', () {
        final builder = PactBuilder.fromPact(
          makePact(const MonthlyByDateSchedule(entries: [
            MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 9)),
            MonthlyDateEntry(dayOfMonth: 28, timeOfDay: Duration(hours: 20)),
          ])),
          today: today,
        );

        final schedule = builder.schedule as SlotSchedule;
        expect(schedule.slots, hasLength(2));
        expect((schedule.slots[0] as MonthlySlot).dayOfMonth, 15);
        expect((schedule.slots[0] as MonthlySlot).timeOfDay, const Duration(hours: 9));
        expect((schedule.slots[1] as MonthlySlot).dayOfMonth, 28);
        expect((schedule.slots[1] as MonthlySlot).timeOfDay, const Duration(hours: 20));
      });

      test('MonthlyByWeekdaySchedule → best-effort MonthlySlots with dayOfMonth=1', () {
        final builder = PactBuilder.fromPact(
          makePact(const MonthlyByWeekdaySchedule(entries: [
            MonthlyWeekdayEntry(occurrence: 2, weekday: DateTime.tuesday, timeOfDay: Duration(hours: 10)),
          ])),
          today: today,
        );

        final schedule = builder.schedule as SlotSchedule;
        expect(schedule.slots, hasLength(1));
        final slot = schedule.slots.first as MonthlySlot;
        expect(slot.dayOfMonth, 1); // fallback — "nth weekday" can't be represented
        expect(slot.timeOfDay, const Duration(hours: 10));
      });

      test('SlotSchedule passes through unchanged', () {
        final original = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 3}, timeOfDay: const Duration(hours: 8)),
          const MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 18)),
        ]);

        final builder = PactBuilder.fromPact(makePact(original), today: today);

        expect(builder.scheduleType, ScheduleType.slot);
        expect(builder.schedule, equals(original));
      });

      test('fromPact preserves all other pact fields', () {
        final pact = Pact(
          id: 'test-pact',
          habitName: 'Meditate',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 11, 1),
          showupDuration: const Duration(minutes: 30),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
          reminderOffset: const Duration(minutes: 15),
        );

        final builder = PactBuilder.fromPact(pact, today: today);

        expect(builder.habitName, 'Meditate');
        expect(builder.startDate, DateTime(2026, 5, 1));
        expect(builder.endDate, DateTime(2026, 11, 1));
        expect(builder.showupDuration, const Duration(minutes: 30));
        expect(builder.reminderOffset, const Duration(minutes: 15));
      });
    });
  });
}
