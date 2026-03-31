import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

void main() {
  group('PactCreationState', () {
    test('has correct defaults', () {
      final today = DateTime(2026, 3, 30);
      final state = PactCreationState(today: today);

      expect(state.habitName, '');
      expect(state.currentStep, 0);
      expect(state.startDate, today);
      expect(state.endDate, DateTime(2026, 9, 30));
      expect(state.showupDuration, isNull);
      expect(state.scheduleType, isNull);
      expect(state.schedule, isNull);
      expect(state.reminderOffset, isNull);
      expect(state.commitmentAccepted, false);
      expect(state.isSubmitting, false);
    });

    test('totalSteps is 5', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(PactCreationState.totalSteps, 5);
      expect(state.currentStep, 0);
    });

    test('copyWith updates only specified fields', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));

      final updated = state.copyWith(
        habitName: 'Meditate',
        currentStep: 1,
      );

      expect(updated.habitName, 'Meditate');
      expect(updated.currentStep, 1);
      expect(updated.startDate, state.startDate);
      expect(updated.endDate, state.endDate);
    });

    group('canAdvanceFromStep', () {
      final base = PactCreationState(today: DateTime(2026, 3, 30));

      test('step 0 (pact duration) requires valid date range', () {
        // Default dates are valid (today < today + 6 months)
        expect(base.canAdvanceFromStep, true);

        final invalidDates = base.copyWith(
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 3, 1),
        );
        expect(invalidDates.canAdvanceFromStep, false);
      });

      test('step 1 (showup duration) requires duration set and <= 2h', () {
        final atStep1 = base.copyWith(
          currentStep: 1,
          showupDuration: const Duration(minutes: 10),
        );
        expect(atStep1.canAdvanceFromStep, true);

        final tooLong = base.copyWith(
          currentStep: 1,
          showupDuration: const Duration(hours: 3),
        );
        expect(tooLong.canAdvanceFromStep, false);

        final noDuration = base.copyWith(currentStep: 1);
        expect(noDuration.canAdvanceFromStep, false);
      });

      test('step 2 (schedule) requires schedule to be set', () {
        final noSchedule = base.copyWith(currentStep: 2);
        expect(noSchedule.canAdvanceFromStep, false);

        final withSchedule = base.copyWith(
          currentStep: 2,
          scheduleType: ScheduleType.daily,
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        );
        expect(withSchedule.canAdvanceFromStep, true);
      });

      test('step 3 (reminder) always allows advancing', () {
        final atStep3 = base.copyWith(currentStep: 3);
        expect(atStep3.canAdvanceFromStep, true);
      });

      test('step 4 (commitment) requires acceptance and habit name', () {
        final notAccepted = base.copyWith(currentStep: 4);
        expect(notAccepted.canAdvanceFromStep, false);

        final acceptedNoName = base.copyWith(
          currentStep: 4,
          commitmentAccepted: true,
        );
        expect(acceptedNoName.canAdvanceFromStep, false);

        final ready = base.copyWith(
          currentStep: 4,
          commitmentAccepted: true,
          habitName: 'Meditate',
        );
        expect(ready.canAdvanceFromStep, true);
      });
    });
  });

  group('ScheduleType', () {
    test('has four values', () {
      expect(ScheduleType.values.length, 4);
      expect(ScheduleType.values, contains(ScheduleType.daily));
      expect(ScheduleType.values, contains(ScheduleType.weekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByWeekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByDate));
    });
  });
}
