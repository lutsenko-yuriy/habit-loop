import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';

class Pact {
  final String id;
  final String habitName;
  final DateTime startDate;
  final DateTime endDate;
  final Duration showupDuration;
  final ShowupSchedule schedule;
  final PactStatus status;
  final Duration? reminderOffset;
  final String? stopReason;

  const Pact({
    required this.id,
    required this.habitName,
    required this.startDate,
    required this.endDate,
    required this.showupDuration,
    required this.schedule,
    required this.status,
    this.reminderOffset,
    this.stopReason,
  });

  Pact copyWith({
    String? id,
    String? habitName,
    DateTime? startDate,
    DateTime? endDate,
    Duration? showupDuration,
    ShowupSchedule? schedule,
    PactStatus? status,
    Duration? reminderOffset,
    String? stopReason,
    bool clearReminderOffset = false,
    bool clearStopReason = false,
  }) {
    return Pact(
      id: id ?? this.id,
      habitName: habitName ?? this.habitName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      reminderOffset:
          clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      stopReason: clearStopReason ? null : (stopReason ?? this.stopReason),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pact &&
          id == other.id &&
          habitName == other.habitName &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          showupDuration == other.showupDuration &&
          schedule == other.schedule &&
          status == other.status &&
          reminderOffset == other.reminderOffset &&
          stopReason == other.stopReason;

  @override
  int get hashCode => Object.hash(
        id,
        habitName,
        startDate,
        endDate,
        showupDuration,
        schedule,
        status,
        reminderOffset,
        stopReason,
      );
}
