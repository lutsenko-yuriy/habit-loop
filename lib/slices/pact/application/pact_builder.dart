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

  /// Creates a [PactBuilder] pre-populated from an existing [pact].
  ///
  /// Used by the edit wizard to seed all fields from the pact being edited.
  /// [today] is used only to satisfy the factory's signature; the pact's own
  /// dates are used directly rather than computing defaults from today.
  ///
  /// **Lazy migration:** legacy schedule types ([DailySchedule], [WeekdaySchedule],
  /// [MonthlyByDateSchedule], [MonthlyByWeekdaySchedule]) are converted to a
  /// [SlotSchedule] so the new card-based wizard UI always receives a uniform
  /// type. The conversion is best-effort:
  /// - [DailySchedule] → one [WeeklySlot] covering all seven weekdays.
  /// - [WeekdaySchedule] → [WeeklySlot]s grouped by `timeOfDay` (entries that
  ///   share the same time are merged into a single slot).
  /// - [MonthlyByDateSchedule] → one [MonthlySlot] per entry.
  /// - [MonthlyByWeekdaySchedule] → one [MonthlySlot] per entry with
  ///   `dayOfMonth = 1` (the "nth weekday of month" pattern cannot be expressed
  ///   in [MonthlySlot]; day 1 is a safe placeholder the user can adjust).
  factory PactBuilder.fromPact(Pact pact, {required DateTime today}) {
    final slotSchedule = _toSlotSchedule(pact.schedule);
    return PactBuilder._internal(
      habitName: pact.habitName,
      startDate: pact.startDate,
      endDate: pact.endDate,
      showupDuration: pact.showupDuration,
      scheduleType: ScheduleType.slot,
      schedule: slotSchedule,
      reminderOffset: pact.reminderOffset,
    );
  }

  /// Converts any [ShowupSchedule] variant to a [SlotSchedule].
  static SlotSchedule _toSlotSchedule(ShowupSchedule schedule) {
    return switch (schedule) {
      SlotSchedule() => schedule,
      DailySchedule(:final timeOfDay) => SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 2, 3, 4, 5, 6, 7}, timeOfDay: timeOfDay),
        ]),
      WeekdaySchedule(:final entries) => SlotSchedule(slots: _weekdayEntriesToSlots(entries)),
      MonthlyByDateSchedule(:final entries) => SlotSchedule(
          slots: entries.map((e) => MonthlySlot(dayOfMonth: e.dayOfMonth, timeOfDay: e.timeOfDay)).toList(),
        ),
      MonthlyByWeekdaySchedule(:final entries) => SlotSchedule(
          // "Nth weekday" can't be expressed as a MonthlySlot; fall back to day 1.
          slots: entries.map((e) => MonthlySlot(dayOfMonth: 1, timeOfDay: e.timeOfDay)).toList(),
        ),
    };
  }

  /// Groups [WeekdayEntry] items by their `timeOfDay`, merging those with the
  /// same time into a single [WeeklySlot] with multiple weekdays.
  static List<WeeklySlot> _weekdayEntriesToSlots(List<WeekdayEntry> entries) {
    final byTime = <Duration, Set<int>>{};
    for (final entry in entries) {
      byTime.putIfAbsent(entry.timeOfDay, () => {}).add(entry.weekday);
    }
    return byTime.entries.map((e) => WeeklySlot(weekdays: e.value, timeOfDay: e.key)).toList();
  }

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
