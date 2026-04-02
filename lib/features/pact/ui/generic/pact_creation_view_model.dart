import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

final pactCreationTodayProvider = Provider<DateTime>((ref) => DateTime.now());

final pactCreationRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override pactCreationRepositoryProvider');
});

final pactCreationShowupRepositoryProvider =
    Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override pactCreationShowupRepositoryProvider');
});

final pactCreationViewModelProvider =
    NotifierProvider<PactCreationViewModel, PactCreationState>(
  PactCreationViewModel.new,
);

class PactCreationViewModel extends Notifier<PactCreationState> {
  @override
  PactCreationState build() {
    final today = ref.read(pactCreationTodayProvider);
    return PactCreationState(today: today);
  }

  void setHabitName(String name) {
    state = state.copyWith(habitName: name);
  }

  void setStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: date);
  }

  void setShowupDuration(Duration duration) {
    state = state.copyWith(showupDuration: duration);
  }

  void setScheduleType(ScheduleType type) {
    final defaultSchedule = switch (type) {
      ScheduleType.daily =>
        const DailySchedule(timeOfDay: Duration(hours: 8)),
      ScheduleType.weekday => const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByWeekday =>
        const MonthlyByWeekdaySchedule(entries: [
          MonthlyWeekdayEntry(
              occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
        ]),
      ScheduleType.monthlyByDate => const MonthlyByDateSchedule(entries: [
          MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
        ]),
    };
    state = state.copyWith(scheduleType: type, schedule: defaultSchedule);
  }

  void setSchedule(ShowupSchedule schedule) {
    state = state.copyWith(schedule: schedule);
  }

  void setReminderOffset(Duration offset) {
    state = state.copyWith(reminderOffset: offset);
  }

  void clearReminderOffset() {
    state = state.copyWith(clearReminderOffset: true);
  }

  void setCommitmentAccepted(bool accepted) {
    state = state.copyWith(commitmentAccepted: accepted);
  }

  void nextStep() {
    if (!state.canAdvanceFromStep) return;
    final nextStep = state.currentStep.next;
    if (nextStep == null) return;
    // Default showup duration to 10 min when entering the showup duration step
    if (nextStep == PactCreationStep.showupDuration &&
        state.showupDuration == null) {
      state = state.copyWith(
        currentStep: nextStep,
        showupDuration: const Duration(minutes: 10),
      );
    } else {
      state = state.copyWith(currentStep: nextStep);
    }
  }

  void previousStep() {
    final prevStep = state.currentStep.previous;
    if (prevStep != null) {
      state = state.copyWith(currentStep: prevStep);
    }
  }

  Future<void> submit() async {
    if (state.schedule == null || state.showupDuration == null) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      final pact = Pact(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        habitName: state.habitName.trim(),
        startDate: state.startDate,
        endDate: state.endDate,
        showupDuration: state.showupDuration!,
        schedule: state.schedule!,
        status: PactStatus.active,
        reminderOffset: state.reminderOffset,
      );

      final repo = ref.read(pactCreationRepositoryProvider);
      await repo.savePact(pact);

      final showups = ShowupGenerator.generate(pact);
      final showupRepo = ref.read(pactCreationShowupRepositoryProvider);
      await showupRepo.saveShowups(showups);
    } catch (e) {
      state = state.copyWith(submitError: e);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
