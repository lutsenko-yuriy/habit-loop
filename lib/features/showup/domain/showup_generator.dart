import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_date_utils.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Generates [Showup] instances from a [Pact]'s schedule.
class ShowupGenerator {
  ShowupGenerator._();

  /// Returns a list of pending [Showup] instances for every scheduled
  /// occurrence within [pact.startDate]…[pact.endDate] (inclusive).
  ///
  /// IDs are deterministic: regenerating for the same pact always produces
  /// the same IDs in the same order.
  ///
  /// Only showups whose reminder window hasn't started yet are included. This
  /// means past showups (or showups whose reminder cutoff has passed) are
  /// silently omitted when [pact.reminderOffset] is set.
  static List<Showup> generate(Pact pact) {
    final now = DateTime.now();
    bool isActionable(DateTime scheduledAt) {
      final cutoff = scheduledAt.subtract(pact.reminderOffset ?? Duration.zero);
      return cutoff.isAfter(now);
    }

    return _generateInRange(
      pact,
      effectiveFrom: pact.startDate,
      effectiveTo: pact.endDate,
      filter: isActionable,
    );
  }

  /// Returns a list of pending [Showup] instances for every scheduled
  /// occurrence that falls within the intersection of [pact.startDate]…[pact.endDate]
  /// and [from]…[to] (all bounds inclusive).
  ///
  /// IDs are deterministic and consistent with [generate]: a showup produced by
  /// [generateWindow] for a given date will always have the same ID as the
  /// same showup produced by [generate] or any other [generateWindow] call,
  /// making regenerating the same window idempotent.
  ///
  /// Unlike [generate], this method does **not** apply the reminder-offset
  /// cutoff filter — it returns all showups scheduled in the window regardless
  /// of whether their reminder time is in the past.
  static List<Showup> generateWindow(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) {
    // Clamp the effective range to the pact boundaries.
    final effectiveFrom =
        from.isBefore(pact.startDate) ? pact.startDate : from;
    final effectiveTo = to.isAfter(pact.endDate) ? pact.endDate : to;

    return _generateInRange(
      pact,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      filter: (_) => true, // no reminder-cutoff filter
    );
  }

  /// Returns the total number of showups scheduled across the full pact
  /// duration ([pact.startDate]…[pact.endDate]) without materialising any
  /// [Showup] objects.
  ///
  /// The count reflects the schedule structure only — it is **not** affected
  /// by [pact.reminderOffset] and never filters past dates. This makes it
  /// suitable for displaying overall totals in stats screens even when only
  /// a window of showups has been persisted.
  static int countTotal(Pact pact) {
    return _countInRange(pact, from: pact.startDate, to: pact.endDate);
  }

  // ---------------------------------------------------------------------------
  // Core range-based generation (used by both generate() and generateWindow())
  // ---------------------------------------------------------------------------

  /// Generates showups for all schedule occurrences in the full pact range,
  /// but emits only those that fall within [effectiveFrom]…[effectiveTo].
  ///
  /// The sequence counter is always advanced for every occurrence in the full
  /// pact range — even skipped ones — so that IDs are deterministic and
  /// independent of the requested window.
  static List<Showup> _generateInRange(
    Pact pact, {
    required DateTime effectiveFrom,
    required DateTime effectiveTo,
    required bool Function(DateTime) filter,
  }) {
    final schedule = pact.schedule;
    var seq = 0;

    // emit() decides whether a candidate scheduledAt should be included in
    // the output given the current window and filter, always advancing seq.
    List<Showup> emitAll(List<DateTime> candidates) {
      final result = <Showup>[];
      for (final scheduledAt in candidates) {
        final currentSeq = seq++;
        if (_isWithinRange(scheduledAt, effectiveFrom, effectiveTo) &&
            filter(scheduledAt)) {
          result.add(_showup(pact: pact, scheduledAt: scheduledAt, seq: currentSeq));
        }
      }
      return result;
    }

    // Build the full list of candidate datetimes across the whole pact range.
    final candidates = switch (schedule) {
      DailySchedule() => _candidatesDaily(pact, schedule),
      WeekdaySchedule() => _candidatesWeekday(pact, schedule),
      MonthlyByWeekdaySchedule() =>
        _candidatesMonthlyByWeekday(pact, schedule),
      MonthlyByDateSchedule() => _candidatesMonthlyByDate(pact, schedule),
    };

    return emitAll(candidates);
  }

  /// Counts schedule occurrences in the full pact range without materialising
  /// [Showup] objects.  No filter is applied — all schedule slots are counted.
  static int _countInRange(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) {
    final schedule = pact.schedule;
    // Clamp range to pact boundaries.
    final effectiveFrom = from.isBefore(pact.startDate) ? pact.startDate : from;
    final effectiveTo = to.isAfter(pact.endDate) ? pact.endDate : to;

    // If the range is inverted after clamping, there is nothing to count.
    if (effectiveTo.isBefore(effectiveFrom)) return 0;

    final candidates = switch (schedule) {
      DailySchedule() => _candidatesDaily(pact, schedule),
      WeekdaySchedule() => _candidatesWeekday(pact, schedule),
      MonthlyByWeekdaySchedule() =>
        _candidatesMonthlyByWeekday(pact, schedule),
      MonthlyByDateSchedule() => _candidatesMonthlyByDate(pact, schedule),
    };

    return candidates
        .where((dt) => _isWithinRange(dt, effectiveFrom, effectiveTo))
        .length;
  }

  // ---------------------------------------------------------------------------
  // Candidate-datetime builders (no filtering, full pact range)
  // ---------------------------------------------------------------------------

  static List<DateTime> _candidatesDaily(Pact pact, DailySchedule schedule) {
    final candidates = <DateTime>[];
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      final scheduledAt = _combine(date, schedule.timeOfDay);
      if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
        candidates.add(scheduledAt);
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
    return candidates;
  }

  static List<DateTime> _candidatesWeekday(
      Pact pact, WeekdaySchedule schedule) {
    final candidates = <DateTime>[];
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      for (final entry in schedule.entries) {
        if (date.weekday == entry.weekday) {
          final scheduledAt = _combine(date, entry.timeOfDay);
          if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
            candidates.add(scheduledAt);
          }
        }
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
    return candidates;
  }

  static List<DateTime> _candidatesMonthlyByWeekday(
    Pact pact,
    MonthlyByWeekdaySchedule schedule,
  ) {
    final candidates = <DateTime>[];
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
          candidates.add(scheduledAt);
        }
      }
    }
    return candidates;
  }

  static List<DateTime> _candidatesMonthlyByDate(
    Pact pact,
    MonthlyByDateSchedule schedule,
  ) {
    final candidates = <DateTime>[];
    final months = _monthsInRange(pact.startDate, pact.endDate);

    for (final month in months) {
      for (final entry in schedule.entries) {
        final candidate = DateTime(month.year, month.month, entry.dayOfMonth);
        if (candidate.month != month.month) continue; // day doesn't exist
        final scheduledAt = _combine(candidate, entry.timeOfDay);
        if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
          candidates.add(scheduledAt);
        }
      }
    }
    return candidates;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
      day = DateTime(day.year, day.month, day.day + 1);
    }
    // Advance to the requested occurrence.
    day = day.add(Duration(days: (occurrence - 1) * 7));
    // If we overflowed into the next month, this occurrence doesn't exist.
    if (day.month != month) return null;
    return day;
  }

  /// Returns one [DateTime] per distinct year-month combination between
  /// [start] and [end] (inclusive).
  static List<DateTime> _monthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var year = start.year;
    var month = start.month;

    while (year < end.year || (year == end.year && month <= end.month)) {
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
    return !dt.isBefore(ShowupDateUtils.startOfDay(start)) &&
        dt.isBefore(ShowupDateUtils.endOfDay(end));
  }

  static Showup _showup({
    required Pact pact,
    required DateTime scheduledAt,
    required int seq,
  }) {
    final datePart =
        '${scheduledAt.year}${_pad(scheduledAt.month)}${_pad(scheduledAt.day)}';
    final timePart =
        '${_pad(scheduledAt.hour)}${_pad(scheduledAt.minute)}${_pad(scheduledAt.second)}';
    return Showup(
      id: '${pact.id}_${datePart}T${timePart}_$seq',
      pactId: pact.id,
      scheduledAt: scheduledAt,
      duration: pact.showupDuration,
      status: ShowupStatus.pending,
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
