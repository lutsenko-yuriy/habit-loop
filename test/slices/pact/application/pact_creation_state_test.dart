import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

void main() {
  group('PactCreationState', () {
    test('totalSteps is 5', () {
      expect(PactCreationState.totalSteps, 5);
    });

    test('default currentStep is pactDuration', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.currentStep, PactCreationStep.pactDuration);
    });

    test('commitmentAccepted defaults to false', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.commitmentAccepted, false);
    });

    test('isSubmitting defaults to false', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.isSubmitting, false);
    });

    test('submitError defaults to null', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.submitError, isNull);
    });

    group('proxy getters delegate to builder', () {
      test('habitName proxies builder.habitName', () {
        final today = DateTime(2026, 3, 30);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(habitName: 'Meditate'),
        );
        expect(state.habitName, 'Meditate');
      });

      test('startDate proxies builder.startDate', () {
        final today = DateTime(2026, 3, 30);
        final newStart = DateTime(2026, 4, 1);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(startDate: newStart),
        );
        expect(state.startDate, newStart);
      });

      test('endDate proxies builder.endDate', () {
        final today = DateTime(2026, 3, 30);
        final newEnd = DateTime(2026, 12, 31);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(endDate: newEnd),
        );
        expect(state.endDate, newEnd);
      });

      test('showupDuration proxies builder.showupDuration', () {
        final today = DateTime(2026, 3, 30);
        const dur = Duration(minutes: 20);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(showupDuration: dur),
        );
        expect(state.showupDuration, dur);
      });

      test('scheduleType proxies builder.scheduleType', () {
        final today = DateTime(2026, 3, 30);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(scheduleType: ScheduleType.weekday),
        );
        expect(state.scheduleType, ScheduleType.weekday);
      });

      test('schedule proxies builder.schedule', () {
        final today = DateTime(2026, 3, 30);
        const schedule = DailySchedule(timeOfDay: Duration(hours: 7));
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(schedule: schedule),
        );
        expect(state.schedule, schedule);
      });

      test('reminderOffset proxies builder.reminderOffset', () {
        final today = DateTime(2026, 3, 30);
        const offset = Duration(minutes: 15);
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(reminderOffset: offset),
        );
        expect(state.reminderOffset, offset);
      });
    });

    group('canAdvanceFromStep dispatches to builder predicates', () {
      final today = DateTime(2026, 3, 30);

      test('pactDuration step delegates to builder.isDateRangeValid (valid)', () {
        final state = PactCreationState(today: today);
        // Default builder has valid date range
        expect(state.currentStep, PactCreationStep.pactDuration);
        expect(state.canAdvanceFromStep, isTrue);
      });

      test('pactDuration step delegates to builder.isDateRangeValid (invalid)', () {
        final state = PactCreationState(
          today: today,
          builder: PactBuilder(today: today).copyWith(
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 3, 1),
          ),
        );
        expect(state.currentStep, PactCreationStep.pactDuration);
        expect(state.canAdvanceFromStep, isFalse);
      });

      test('showupDuration step delegates to builder.isShowupDurationValid (valid)', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.showupDuration,
          builder: PactBuilder(today: today).copyWith(showupDuration: const Duration(minutes: 10)),
        );
        expect(state.canAdvanceFromStep, isTrue);
      });

      test('showupDuration step delegates to builder.isShowupDurationValid (null)', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.showupDuration,
        );
        expect(state.canAdvanceFromStep, isFalse);
      });

      test('showupDuration step delegates to builder.isShowupDurationValid (too long)', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.showupDuration,
          builder: PactBuilder(today: today).copyWith(showupDuration: const Duration(hours: 3)),
        );
        expect(state.canAdvanceFromStep, isFalse);
      });

      test('schedule step delegates to builder.isScheduleSet (not set)', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.schedule,
        );
        expect(state.canAdvanceFromStep, isFalse);
      });

      test('schedule step delegates to builder.isScheduleSet (set)', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.schedule,
          builder: PactBuilder(today: today).copyWith(
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          ),
        );
        expect(state.canAdvanceFromStep, isTrue);
      });

      test('reminder step always returns true', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.reminder,
        );
        expect(state.canAdvanceFromStep, isTrue);
      });

      test('commitment step requires commitmentAccepted AND builder.isHabitNameValid', () {
        // Neither accepted nor name
        final neitherState = PactCreationState(
          today: today,
          currentStep: PactCreationStep.commitment,
        );
        expect(neitherState.canAdvanceFromStep, isFalse);

        // Accepted but no name
        final acceptedNoName = PactCreationState(
          today: today,
          currentStep: PactCreationStep.commitment,
          commitmentAccepted: true,
        );
        expect(acceptedNoName.canAdvanceFromStep, isFalse);

        // Name but not accepted
        final nameNotAccepted = PactCreationState(
          today: today,
          currentStep: PactCreationStep.commitment,
          builder: PactBuilder(today: today).copyWith(habitName: 'Meditate'),
        );
        expect(nameNotAccepted.canAdvanceFromStep, isFalse);

        // Both name and accepted
        final ready = PactCreationState(
          today: today,
          currentStep: PactCreationStep.commitment,
          commitmentAccepted: true,
          builder: PactBuilder(today: today).copyWith(habitName: 'Meditate'),
        );
        expect(ready.canAdvanceFromStep, isTrue);
      });
    });

    group('copyWith (wizard concerns only)', () {
      final today = DateTime(2026, 3, 30);

      test('updates currentStep', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(currentStep: PactCreationStep.schedule);
        expect(updated.currentStep, PactCreationStep.schedule);
        expect(updated.builder.habitName, state.builder.habitName);
      });

      test('updates builder', () {
        final state = PactCreationState(today: today);
        final newBuilder = state.builder.copyWith(habitName: 'Meditate');
        final updated = state.copyWith(builder: newBuilder);
        expect(updated.habitName, 'Meditate');
        expect(updated.currentStep, state.currentStep);
      });

      test('updates commitmentAccepted', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(commitmentAccepted: true);
        expect(updated.commitmentAccepted, isTrue);
      });

      test('updates isSubmitting', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(isSubmitting: true);
        expect(updated.isSubmitting, isTrue);
      });

      test('updates submitError', () {
        final state = PactCreationState(today: today);
        final error = Exception('test error');
        final updated = state.copyWith(submitError: error);
        expect(updated.submitError, error);
      });

      test('clearSubmitError sets submitError to null', () {
        final state = PactCreationState(today: today).copyWith(submitError: Exception('err'));
        expect(state.submitError, isNotNull);
        final cleared = state.copyWith(clearSubmitError: true);
        expect(cleared.submitError, isNull);
      });

      test('unspecified fields are preserved', () {
        final state = PactCreationState(
          today: today,
          currentStep: PactCreationStep.schedule,
          commitmentAccepted: true,
        );
        final updated = state.copyWith(isSubmitting: true);
        expect(updated.currentStep, PactCreationStep.schedule);
        expect(updated.commitmentAccepted, isTrue);
      });
    });
  });

  group('ScheduleType re-exported from pact_creation_state', () {
    test('has four values', () {
      expect(ScheduleType.values.length, 4);
      expect(ScheduleType.values, contains(ScheduleType.daily));
      expect(ScheduleType.values, contains(ScheduleType.weekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByWeekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByDate));
    });
  });
}
