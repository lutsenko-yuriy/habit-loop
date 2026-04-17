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

  /// The wall-clock instant at which this pact was created.
  ///
  /// Used to prevent showups scheduled *before* the pact was created from
  /// ever being persisted — e.g. a daily-8am pact created at 10pm must not
  /// generate a failing 8am showup for the same day.
  ///
  /// `null` for pacts loaded from storage that pre-date this field; callers
  /// treat `null` as equivalent to `startDate` (no intra-day filtering).
  final DateTime? createdAt;

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
    this.createdAt,
  });

  /// Returns a copy of this pact with the given fields replaced.
  ///
  /// [id] is immutable and cannot be changed after creation — it is the
  /// identity of a pact and is used as a foreign key by its showups.
  Pact copyWith({
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
      id: id,
      habitName: habitName ?? this.habitName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      reminderOffset:
          clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      stopReason: clearStopReason ? null : (stopReason ?? this.stopReason),
      createdAt: createdAt, // immutable — never overridden by copyWith
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
          stopReason == other.stopReason &&
          createdAt == other.createdAt;

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
        createdAt,
      );
}
