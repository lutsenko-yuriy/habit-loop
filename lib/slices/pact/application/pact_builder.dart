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

// Pact-data fields and validity predicates for the wizard.
// Wizard-navigation concerns (step, commitment, submit state) live in [PactCreationState].
class PactBuilder {
  final String habitName;

  // Always midnight — no time component.
  final DateTime startDate;

  final DateTime endDate;
  final Duration? showupDuration;
  final ScheduleType? scheduleType;
  final ShowupSchedule? schedule;

  // null means no reminder.
  final Duration? reminderOffset;

  // startDate normalized to midnight; endDate defaults to 6 months after today (month-end clamped).
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

  /// Lazy-migrates legacy schedule types to [SlotSchedule] for the card-based wizard:
  /// - [DailySchedule] → one [WeeklySlot] covering all seven weekdays.
  /// - [WeekdaySchedule] → [WeeklySlot]s grouped by `timeOfDay`.
  /// - [MonthlyByDateSchedule] → one [MonthlySlot] per entry.
  /// - [MonthlyByWeekdaySchedule] → [MonthlySlot] with `dayOfMonth = 1`
  ///   ("nth weekday" can't be expressed as a [MonthlySlot]; placeholder for user to adjust).
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

  bool get isDateRangeValid => startDate.isBefore(endDate);

  bool get isShowupDurationValid =>
      showupDuration != null && showupDuration!.inMinutes >= 1 && showupDuration!.inMinutes <= 120;

  // Also returns false for SlotSchedule with zero slots (empty card list).
  bool get isScheduleSet {
    if (schedule == null) return false;
    if (schedule case SlotSchedule(:final slots)) return slots.isNotEmpty;
    return true;
  }

  bool get isHabitNameValid => habitName.trim().isNotEmpty;

  bool get isComplete => isHabitNameValid && isDateRangeValid && isShowupDurationValid && isScheduleSet;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  // Throws StateError if isComplete is false.
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

  // Use clearSchedule/clearReminderOffset to reset those fields to null.
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
