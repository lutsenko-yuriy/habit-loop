import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

/// Returns [date] advanced by [months], clamping the day to the last day of
/// the target month if the original day does not exist there (e.g. Aug 31 + 6
/// months → Feb 28, not Mar 3).
DateTime _addMonths(DateTime date, int months) {
  final rawMonth = date.month + months;
  final year = date.year + (rawMonth - 1) ~/ 12;
  final month = (rawMonth - 1) % 12 + 1;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day.clamp(1, daysInMonth));
}

enum PactCreationStep {
  pactDuration(0),
  showupDuration(1),
  schedule(2),
  reminder(3),
  commitment(4);

  const PactCreationStep(this.value);
  final int value;

  static int get count => PactCreationStep.values.length;

  bool get isFirst => this == PactCreationStep.values.first;
  bool get isLast => this == PactCreationStep.values.last;

  PactCreationStep? get next {
    final i = index + 1;
    return i < PactCreationStep.values.length ? PactCreationStep.values[i] : null;
  }

  PactCreationStep? get previous {
    final i = index - 1;
    return i >= 0 ? PactCreationStep.values[i] : null;
  }
}

enum ScheduleType { daily, weekday, monthlyByWeekday, monthlyByDate }

class PactCreationState {
  static int get totalSteps => PactCreationStep.count;

  final String habitName;
  final PactCreationStep currentStep;
  final DateTime startDate;
  final DateTime endDate;
  final Duration? showupDuration;
  final ScheduleType? scheduleType;
  final ShowupSchedule? schedule;
  final Duration? reminderOffset;
  final bool commitmentAccepted;
  final bool isSubmitting;
  final Object? submitError;

  PactCreationState({
    required DateTime today,
    this.habitName = '',
    this.currentStep = PactCreationStep.pactDuration,
    DateTime? startDate,
    DateTime? endDate,
    this.showupDuration,
    this.scheduleType,
    this.schedule,
    this.reminderOffset,
    this.commitmentAccepted = false,
    this.isSubmitting = false,
    this.submitError,
  })  : startDate = startDate ?? DateTime(today.year, today.month, today.day),
        endDate = endDate ?? _addMonths(today, 6);

  bool get canAdvanceFromStep {
    switch (currentStep) {
      case PactCreationStep.pactDuration:
        return startDate.isBefore(endDate);
      case PactCreationStep.showupDuration:
        return showupDuration != null && showupDuration!.inMinutes >= 1 && showupDuration!.inMinutes <= 120;
      case PactCreationStep.schedule:
        return schedule != null;
      case PactCreationStep.reminder:
        return true;
      case PactCreationStep.commitment:
        return commitmentAccepted && habitName.trim().isNotEmpty;
    }
  }

  PactCreationState copyWith({
    String? habitName,
    PactCreationStep? currentStep,
    DateTime? startDate,
    DateTime? endDate,
    Duration? showupDuration,
    ScheduleType? scheduleType,
    ShowupSchedule? schedule,
    Duration? reminderOffset,
    bool? commitmentAccepted,
    bool? isSubmitting,
    Object? submitError,
    bool clearSchedule = false,
    bool clearReminderOffset = false,
    bool clearSubmitError = false,
  }) {
    return PactCreationState._internal(
      habitName: habitName ?? this.habitName,
      currentStep: currentStep ?? this.currentStep,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      scheduleType: scheduleType ?? this.scheduleType,
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
      reminderOffset: clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      commitmentAccepted: commitmentAccepted ?? this.commitmentAccepted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  const PactCreationState._internal({
    required this.habitName,
    required this.currentStep,
    required this.startDate,
    required this.endDate,
    required this.showupDuration,
    required this.scheduleType,
    required this.schedule,
    required this.reminderOffset,
    required this.commitmentAccepted,
    required this.isSubmitting,
    required this.submitError,
  });
}
