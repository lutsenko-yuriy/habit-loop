import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

void main() {
  group('PactCreationState', () {
    test('totalSteps is 6', () {
      expect(PactCreationState.totalSteps, 6);
    });

    test('default currentStep is habitName', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.currentStep, PactWizardStep.habitName);
    });

    test('commitmentAccepted defaults to false', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.commitmentAccepted, false);
    });

    test('usedSummaryJump defaults to false', () {
      final state = PactCreationState(today: DateTime(2026, 3, 30));
      expect(state.usedSummaryJump, false);
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

    group('PactWizardStep enum', () {
      test('has 6 values', () {
        expect(PactWizardStep.values.length, 6);
      });

      test('values are in expected order', () {
        expect(PactWizardStep.values[0], PactWizardStep.habitName);
        expect(PactWizardStep.values[1], PactWizardStep.duration);
        expect(PactWizardStep.values[2], PactWizardStep.showupDuration);
        expect(PactWizardStep.values[3], PactWizardStep.schedule);
        expect(PactWizardStep.values[4], PactWizardStep.reminder);
        expect(PactWizardStep.values[5], PactWizardStep.summary);
      });

      test('value indices match expected page order', () {
        expect(PactWizardStep.habitName.value, 0);
        expect(PactWizardStep.duration.value, 1);
        expect(PactWizardStep.showupDuration.value, 2);
        expect(PactWizardStep.schedule.value, 3);
        expect(PactWizardStep.reminder.value, 4);
        expect(PactWizardStep.summary.value, 5);
      });

      test('isFirst is true only for habitName', () {
        expect(PactWizardStep.habitName.isFirst, isTrue);
        expect(PactWizardStep.duration.isFirst, isFalse);
        expect(PactWizardStep.summary.isFirst, isFalse);
      });

      test('isLast is true only for summary', () {
        expect(PactWizardStep.summary.isLast, isTrue);
        expect(PactWizardStep.reminder.isLast, isFalse);
        expect(PactWizardStep.habitName.isLast, isFalse);
      });
    });

    group('usedSummaryJump', () {
      final today = DateTime(2026, 3, 30);

      test('defaults to false', () {
        final state = PactCreationState(today: today);
        expect(state.usedSummaryJump, false);
      });

      test('copyWith can set to true', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(usedSummaryJump: true);
        expect(updated.usedSummaryJump, true);
      });

      test('copyWith preserves true when not specified', () {
        final state = PactCreationState(today: today).copyWith(usedSummaryJump: true);
        final updated = state.copyWith(isSubmitting: true);
        expect(updated.usedSummaryJump, true);
      });
    });

    group('copyWith (wizard concerns only)', () {
      final today = DateTime(2026, 3, 30);

      test('updates currentStep', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(currentStep: PactWizardStep.schedule);
        expect(updated.currentStep, PactWizardStep.schedule);
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

      test('updates usedSummaryJump', () {
        final state = PactCreationState(today: today);
        final updated = state.copyWith(usedSummaryJump: true);
        expect(updated.usedSummaryJump, isTrue);
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
          currentStep: PactWizardStep.schedule,
          commitmentAccepted: true,
          usedSummaryJump: true,
        );
        final updated = state.copyWith(isSubmitting: true);
        expect(updated.currentStep, PactWizardStep.schedule);
        expect(updated.commitmentAccepted, isTrue);
        expect(updated.usedSummaryJump, isTrue);
      });
    });
  });

  group('ScheduleType re-exported from pact_creation_state', () {
    test('has five values (four legacy + slot)', () {
      expect(ScheduleType.values.length, 5);
      expect(ScheduleType.values, contains(ScheduleType.daily));
      expect(ScheduleType.values, contains(ScheduleType.weekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByWeekday));
      expect(ScheduleType.values, contains(ScheduleType.monthlyByDate));
      expect(ScheduleType.values, contains(ScheduleType.slot));
    });
  });
}
