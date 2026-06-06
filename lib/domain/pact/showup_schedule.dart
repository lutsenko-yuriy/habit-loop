/// `timeOfDay` is hours/minutes/seconds only — sub-second precision is ignored.
/// Valid range: `0 <= hours <= 23`, `0 <= minutes <= 59`, `0 <= seconds <= 59`.
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

// Duplicate weekday+time entries produce two separate showups with unique IDs.
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

sealed class ScheduleSlot {
  const ScheduleSlot();
}

// Equality is set-based: same timeOfDay + same weekday set regardless of insertion order.
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

// Months where dayOfMonth doesn't exist (e.g. Feb 31) are silently skipped by ShowupGenerator.
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

// Existing pacts with legacy schedule types continue to load correctly (backward compatible).
class SlotSchedule extends ShowupSchedule {
  final List<ScheduleSlot> slots;

  const SlotSchedule({required this.slots});

  @override
  bool operator ==(Object other) => identical(this, other) || other is SlotSchedule && _slotsEqual(other.slots);

  bool _slotsEqual(List<ScheduleSlot> other) {
    if (slots.length != other.length) return false;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slots);
}
