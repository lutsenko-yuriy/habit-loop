import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Generates [Showup] instances from a [Pact]'s schedule.
class ShowupGenerator {
  ShowupGenerator._();

  /// Returns a list of pending [Showup] instances for every scheduled
  /// occurrence within [pact.startDate]…[pact.endDate] (inclusive).
  static List<Showup> generate(Pact pact) {
    final schedule = pact.schedule;
    return switch (schedule) {
      DailySchedule() => _generateDaily(pact, schedule),
      WeekdaySchedule() => _generateWeekday(pact, schedule),
      MonthlyByWeekdaySchedule() =>
        _generateMonthlyByWeekday(pact, schedule),
      MonthlyByDateSchedule() => _generateMonthlyByDate(pact, schedule),
    };
  }

  // ---------------------------------------------------------------------------
  // Daily
  // ---------------------------------------------------------------------------

  static List<Showup> _generateDaily(Pact pact, DailySchedule schedule) {
    final showups = <Showup>[];
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      showups.add(_showup(
        pact: pact,
        scheduledAt: _combine(date, schedule.timeOfDay),
      ));
      date = date.add(const Duration(days: 1));
    }
    return showups;
  }

  // ---------------------------------------------------------------------------
  // Weekday
  // ---------------------------------------------------------------------------

  static List<Showup> _generateWeekday(Pact pact, WeekdaySchedule schedule) {
    final showups = <Showup>[];
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      for (final entry in schedule.entries) {
        if (date.weekday == entry.weekday) {
          showups.add(_showup(
            pact: pact,
            scheduledAt: _combine(date, entry.timeOfDay),
          ));
        }
      }
      date = date.add(const Duration(days: 1));
    }
    return showups;
  }

  // ---------------------------------------------------------------------------
  // Monthly by weekday occurrence (e.g. "2nd Monday")
  // ---------------------------------------------------------------------------

  static List<Showup> _generateMonthlyByWeekday(
    Pact pact,
    MonthlyByWeekdaySchedule schedule,
  ) {
    final showups = <Showup>[];
    final months = _monthsInRange(pact.startDate, pact.endDate);

    for (final month in months) {
      for (final entry in schedule.entries) {
        final date = _nthWeekdayOfMonth(
          year: month.year,
          month: month.month,
          weekday: entry.weekday,
          occurrence: entry.occurrence,
        );
        if (date == null) continue;
        final scheduledAt = _combine(date, entry.timeOfDay);
        if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
          showups.add(_showup(pact: pact, scheduledAt: scheduledAt));
        }
      }
    }
    return showups;
  }

  /// Returns the [occurrence]-th [weekday] of the given month/year,
  /// or null if it does not exist (e.g. 5th Monday in a 4-Monday month).
  static DateTime? _nthWeekdayOfMonth({
    required int year,
    required int month,
    required int weekday,
    required int occurrence,
  }) {
    // Find the first occurrence of the weekday in the month.
    var day = DateTime(year, month, 1);
    while (day.weekday != weekday) {
      day = day.add(const Duration(days: 1));
    }
    // Advance to the requested occurrence.
    day = day.add(Duration(days: (occurrence - 1) * 7));
    // If we overflowed into the next month, this occurrence doesn't exist.
    if (day.month != month) return null;
    return day;
  }

  // ---------------------------------------------------------------------------
  // Monthly by date (e.g. "25th of each month")
  // ---------------------------------------------------------------------------

  static List<Showup> _generateMonthlyByDate(
    Pact pact,
    MonthlyByDateSchedule schedule,
  ) {
    final showups = <Showup>[];
    final months = _monthsInRange(pact.startDate, pact.endDate);

    for (final month in months) {
      for (final entry in schedule.entries) {
        // Check that the day exists in this month by comparing months after
        // construction (DateTime overflows to the next month for invalid days).
        final candidate = DateTime(month.year, month.month, entry.dayOfMonth);
        if (candidate.month != month.month) continue; // day doesn't exist

        final scheduledAt = _combine(candidate, entry.timeOfDay);
        if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
          showups.add(_showup(pact: pact, scheduledAt: scheduledAt));
        }
      }
    }
    return showups;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns one [DateTime] per distinct year-month combination between
  /// [start] and [end] (inclusive).
  static List<DateTime> _monthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var year = start.year;
    var month = start.month;

    while (DateTime(year, month).isBefore(DateTime(end.year, end.month + 1))) {
      months.add(DateTime(year, month));
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return months;
  }

  /// Combines a date and a time-of-day [Duration] into a single [DateTime].
  ///
  /// Preserves hours, minutes, and seconds. Sub-second precision is not
  /// supported — [timeOfDay] should only contain hours, minutes, and seconds.
  static DateTime _combine(DateTime date, Duration timeOfDay) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay.inHours,
      timeOfDay.inMinutes.remainder(60),
      timeOfDay.inSeconds.remainder(60),
    );
  }

  /// Returns true if [dt] is within [start]…[end] day boundaries (inclusive).
  static bool _isWithinRange(DateTime dt, DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return !dt.isBefore(startDay) && !dt.isAfter(endDay);
  }

  static Showup _showup({required Pact pact, required DateTime scheduledAt}) {
    return Showup(
      id: '${pact.id}_${scheduledAt.millisecondsSinceEpoch}',
      pactId: pact.id,
      scheduledAt: scheduledAt,
      duration: pact.showupDuration,
      status: ShowupStatus.pending,
    );
  }
}
