import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';

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

/// Holds the pact-data fields entered by the user during the creation wizard.
///
/// [PactBuilder] owns:
/// - the 7 pact-data fields (habit name, dates, durations, schedule, reminder)
/// - the validity predicates used by each wizard step
/// - the [build] factory that assembles a [Pact] once all fields are valid
///
/// It is deliberately decoupled from wizard-navigation concerns (current step,
/// commitment acceptance, submission state), which remain in [PactCreationState].
class PactBuilder {
  /// The habit name the user intends to build.
  final String habitName;

  /// The date on which the pact starts (always midnight — no time component).
  final DateTime startDate;

  /// The date on which the pact ends.
  final DateTime endDate;

  /// The length of a single showup.
  final Duration? showupDuration;

  /// The type of recurrence schedule chosen by the user.
  final ScheduleType? scheduleType;

  /// The concrete recurrence schedule (daily, weekday, or monthly).
  final ShowupSchedule? schedule;

  /// How far in advance the user wants to be reminded; `null` means no reminder.
  final Duration? reminderOffset;

  /// Creates a [PactBuilder] with sensible defaults derived from [today].
  ///
  /// [startDate] is normalized to midnight. [endDate] defaults to 6 months
  /// after [today] with month-end clamping (e.g. Aug 31 → Feb 28).
  PactBuilder({
    required DateTime today,
    String? habitName,
    DateTime? startDate,
    DateTime? endDate,
    this.showupDuration,
    this.scheduleType,
    this.schedule,
    this.reminderOffset,
  })  : habitName = habitName ?? '',
        startDate = startDate ?? DateTime(today.year, today.month, today.day),
        endDate = endDate ?? _addMonths(today, 6);

  PactBuilder._internal({
    required this.habitName,
    required this.startDate,
    required this.endDate,
    required this.showupDuration,
    required this.scheduleType,
    required this.schedule,
    required this.reminderOffset,
  });

  // ---------------------------------------------------------------------------
  // Validity predicates
  // ---------------------------------------------------------------------------

  /// Whether the pact's date range is logically valid.
  bool get isDateRangeValid => startDate.isBefore(endDate);

  /// Whether the showup duration is within the allowed range (1–120 minutes).
  bool get isShowupDurationValid =>
      showupDuration != null && showupDuration!.inMinutes >= 1 && showupDuration!.inMinutes <= 120;

  /// Whether a schedule has been chosen.
  bool get isScheduleSet => schedule != null;

  /// Whether a non-blank habit name has been entered.
  bool get isHabitNameValid => habitName.trim().isNotEmpty;

  /// Whether all fields are valid and the pact can be built.
  bool get isComplete => isHabitNameValid && isDateRangeValid && isShowupDurationValid && isScheduleSet;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Assembles a [Pact] from the current field values.
  ///
  /// Throws a [StateError] if [isComplete] is false.
  Pact build({required String id, required DateTime createdAt}) {
    if (!isComplete) {
      throw StateError('Cannot build a Pact from an incomplete PactBuilder. '
          'Check isComplete before calling build().');
    }
    return Pact(
      id: id,
      habitName: habitName.trim(),
      startDate: startDate,
      endDate: endDate,
      showupDuration: showupDuration!,
      schedule: schedule!,
      status: PactStatus.active,
      reminderOffset: reminderOffset,
      createdAt: createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  /// Returns a copy of this builder with the specified fields replaced.
  ///
  /// Use [clearSchedule] to set [schedule] back to `null`.
  /// Use [clearReminderOffset] to set [reminderOffset] back to `null`.
  PactBuilder copyWith({
    String? habitName,
    DateTime? startDate,
    DateTime? endDate,
    Duration? showupDuration,
    ScheduleType? scheduleType,
    ShowupSchedule? schedule,
    Duration? reminderOffset,
    bool clearSchedule = false,
    bool clearReminderOffset = false,
  }) {
    return PactBuilder._internal(
      habitName: habitName ?? this.habitName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      showupDuration: showupDuration ?? this.showupDuration,
      scheduleType: scheduleType ?? this.scheduleType,
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
      reminderOffset: clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
    );
  }
}
