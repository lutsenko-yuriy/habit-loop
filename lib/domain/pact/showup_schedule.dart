/// Base class for all showup recurrence schedules.
///
/// All `timeOfDay` fields in subclasses represent the time within a day as a
/// [Duration]. Only hours, minutes, and seconds are meaningful — sub-second
/// precision is ignored during schedule generation. Values must satisfy:
/// `0 <= hours <= 23`, `0 <= minutes <= 59`, `0 <= seconds <= 59`.
sealed class ShowupSchedule {
  const ShowupSchedule();
}

class DailySchedule extends ShowupSchedule {
  final Duration timeOfDay;

  const DailySchedule({required this.timeOfDay});

  @override
  bool operator ==(Object other) => identical(this, other) || other is DailySchedule && timeOfDay == other.timeOfDay;

  @override
  int get hashCode => timeOfDay.hashCode;
}

/// A schedule that triggers on specific weekdays.
///
/// If [entries] contains two entries for the same weekday and time-of-day,
/// [ShowupGenerator] will produce two separate showups for that occurrence,
/// each with a unique ID.
class WeekdaySchedule extends ShowupSchedule {
  final List<WeekdayEntry> entries;

  const WeekdaySchedule({required this.entries});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekdaySchedule && entries.length == other.entries.length && _entriesEqual(other.entries);

  bool _entriesEqual(List<WeekdayEntry> other) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}

class WeekdayEntry {
  final int weekday;
  final Duration timeOfDay;

  const WeekdayEntry({required this.weekday, required this.timeOfDay});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeekdayEntry && weekday == other.weekday && timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(weekday, timeOfDay);
}

class MonthlyByWeekdaySchedule extends ShowupSchedule {
  final List<MonthlyWeekdayEntry> entries;

  const MonthlyByWeekdaySchedule({required this.entries});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyByWeekdaySchedule && entries.length == other.entries.length && _entriesEqual(other.entries);

  bool _entriesEqual(List<MonthlyWeekdayEntry> other) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}

class MonthlyWeekdayEntry {
  final int occurrence;
  final int weekday;
  final Duration timeOfDay;

  const MonthlyWeekdayEntry({
    required this.occurrence,
    required this.weekday,
    required this.timeOfDay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyWeekdayEntry &&
          occurrence == other.occurrence &&
          weekday == other.weekday &&
          timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(occurrence, weekday, timeOfDay);
}

class MonthlyByDateSchedule extends ShowupSchedule {
  final List<MonthlyDateEntry> entries;

  const MonthlyByDateSchedule({required this.entries});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyByDateSchedule && entries.length == other.entries.length && _entriesEqual(other.entries);

  bool _entriesEqual(List<MonthlyDateEntry> other) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}

class MonthlyDateEntry {
  final int dayOfMonth;
  final Duration timeOfDay;

  const MonthlyDateEntry({
    required this.dayOfMonth,
    required this.timeOfDay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyDateEntry && dayOfMonth == other.dayOfMonth && timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(dayOfMonth, timeOfDay);
}

// ---------------------------------------------------------------------------
// Card-based schedule (new UX — HAB-80)
// ---------------------------------------------------------------------------

/// Base class for individual schedule cards in a [SlotSchedule].
///
/// A [ScheduleSlot] is either a [WeeklySlot] (fires on specific weekdays) or a
/// [MonthlySlot] (fires on a specific day of the month).
sealed class ScheduleSlot {
  const ScheduleSlot();
}

/// A schedule card that triggers on the given [weekdays] at [timeOfDay].
///
/// [weekdays] uses [DateTime.weekday] values (1 = Monday … 7 = Sunday).
/// All selected days share a single start time.
///
/// Equality is set-based: two [WeeklySlot]s are equal when they have the same
/// [timeOfDay] and exactly the same set of [weekdays], regardless of insertion
/// order.
class WeeklySlot extends ScheduleSlot {
  final Set<int> weekdays;
  final Duration timeOfDay;

  WeeklySlot({required this.weekdays, required this.timeOfDay});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklySlot &&
          timeOfDay == other.timeOfDay &&
          weekdays.length == other.weekdays.length &&
          weekdays.containsAll(other.weekdays);

  @override
  int get hashCode => Object.hash(timeOfDay, Object.hashAll([...weekdays]..sort()));
}

/// A schedule card that triggers on a specific [dayOfMonth] at [timeOfDay].
///
/// Months where [dayOfMonth] does not exist (e.g. February 31) are silently
/// skipped by [ShowupGenerator].
class MonthlySlot extends ScheduleSlot {
  final int dayOfMonth;
  final Duration timeOfDay;

  const MonthlySlot({required this.dayOfMonth, required this.timeOfDay});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MonthlySlot && dayOfMonth == other.dayOfMonth && timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(dayOfMonth, timeOfDay);
}

/// A schedule composed of one or more [ScheduleSlot] cards.
///
/// Replaces the legacy single-mode schedules ([DailySchedule],
/// [WeekdaySchedule], [MonthlyByDateSchedule]) in the new pact creation and
/// edit wizard. Existing pacts stored with the old schedule types continue to
/// load correctly — [ScheduleCodec] decodes them as before; [PactBuilder.fromPact]
/// maps them to [SlotSchedule] when the user opens the edit wizard.
class SlotSchedule extends ShowupSchedule {
  final List<ScheduleSlot> slots;

  const SlotSchedule({required this.slots});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SlotSchedule && slots.length == other.slots.length && _slotsEqual(other.slots);

  bool _slotsEqual(List<ScheduleSlot> other) {
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slots);
}
