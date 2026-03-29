sealed class ShowupSchedule {
  const ShowupSchedule();
}

class DailySchedule extends ShowupSchedule {
  final Duration timeOfDay;

  const DailySchedule({required this.timeOfDay});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailySchedule && timeOfDay == other.timeOfDay;

  @override
  int get hashCode => timeOfDay.hashCode;
}

class WeekdaySchedule extends ShowupSchedule {
  final List<WeekdayEntry> entries;

  const WeekdaySchedule({required this.entries});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekdaySchedule &&
          entries.length == other.entries.length &&
          _entriesEqual(other.entries);

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
      identical(this, other) ||
      other is WeekdayEntry &&
          weekday == other.weekday &&
          timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(weekday, timeOfDay);
}

class MonthlyByWeekdaySchedule extends ShowupSchedule {
  final List<MonthlyWeekdayEntry> entries;

  const MonthlyByWeekdaySchedule({required this.entries});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyByWeekdaySchedule &&
          entries.length == other.entries.length &&
          _entriesEqual(other.entries);

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
      other is MonthlyByDateSchedule &&
          entries.length == other.entries.length &&
          _entriesEqual(other.entries);

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
      other is MonthlyDateEntry &&
          dayOfMonth == other.dayOfMonth &&
          timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(dayOfMonth, timeOfDay);
}
