import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';

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
  final PactStats? stats;

  // Prevents showups before pact creation from being persisted (e.g. daily-8am pact created at 10pm).
  // null for pre-date pacts; callers treat null as equivalent to startDate.
  final DateTime? createdAt;

  // null unless status is stopped; preserves endDate as the original planned end date.
  final DateTime? stoppedAt;

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
    this.stats,
    this.createdAt,
    this.stoppedAt,
  });

  // id is immutable — identity and foreign key for all showups of this pact.
  Pact copyWith({
    String? habitName,
    DateTime? startDate,
    DateTime? endDate,
    Duration? showupDuration,
    ShowupSchedule? schedule,
    PactStatus? status,
    Duration? reminderOffset,
    String? stopReason,
    PactStats? stats,
    DateTime? stoppedAt,
    bool clearReminderOffset = false,
    bool clearStopReason = false,
    bool clearStats = false,
    bool clearStoppedAt = false,
  }) {
    return Pact(
      id: id,
      habitName: habitName ?? this.habitName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      reminderOffset: clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      stopReason: clearStopReason ? null : (stopReason ?? this.stopReason),
      stats: clearStats ? null : (stats ?? this.stats),
      createdAt: createdAt, // immutable — never overridden by copyWith
      stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
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
          stats == other.stats &&
          createdAt == other.createdAt &&
          stoppedAt == other.stoppedAt;

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
        stats,
        createdAt,
        stoppedAt,
      );
}
