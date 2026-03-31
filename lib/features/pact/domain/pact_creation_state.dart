import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

enum ScheduleType { daily, weekday, monthlyByWeekday, monthlyByDate }

class PactCreationState {
  static const int totalSteps = 5;

  final String habitName;
  final int currentStep;
  final DateTime startDate;
  final DateTime endDate;
  final Duration? showupDuration;
  final ScheduleType? scheduleType;
  final ShowupSchedule? schedule;
  final Duration? reminderOffset;
  final bool commitmentAccepted;
  final bool isSubmitting;

  PactCreationState({
    required DateTime today,
    this.habitName = '',
    this.currentStep = 0,
    DateTime? startDate,
    DateTime? endDate,
    this.showupDuration,
    this.scheduleType,
    this.schedule,
    this.reminderOffset,
    this.commitmentAccepted = false,
    this.isSubmitting = false,
  })  : startDate = startDate ?? today,
        endDate = endDate ??
            DateTime(today.year, today.month + 6, today.day);

  bool get canAdvanceFromStep {
    switch (currentStep) {
      case 0:
        return startDate.isBefore(endDate);
      case 1:
        return showupDuration != null &&
            showupDuration!.inMinutes >= 1 &&
            showupDuration!.inMinutes <= 120;
      case 2:
        return schedule != null;
      case 3:
        return true;
      case 4:
        return commitmentAccepted && habitName.trim().isNotEmpty;
      default:
        return false;
    }
  }

  PactCreationState copyWith({
    String? habitName,
    int? currentStep,
    DateTime? startDate,
    DateTime? endDate,
    Duration? showupDuration,
    ScheduleType? scheduleType,
    ShowupSchedule? schedule,
    Duration? reminderOffset,
    bool? commitmentAccepted,
    bool? isSubmitting,
    bool clearSchedule = false,
    bool clearReminderOffset = false,
  }) {
    return PactCreationState._internal(
      habitName: habitName ?? this.habitName,
      currentStep: currentStep ?? this.currentStep,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      scheduleType: scheduleType ?? this.scheduleType,
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
      reminderOffset: clearReminderOffset
          ? null
          : (reminderOffset ?? this.reminderOffset),
      commitmentAccepted: commitmentAccepted ?? this.commitmentAccepted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  PactCreationState._internal({
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
  });
}
