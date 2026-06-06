import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_date_utils.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

class ShowupGenerator {
  ShowupGenerator._();

  /// IDs are deterministic. Showups past their reminder cutoff are silently omitted.
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

  /// Unlike [generate], does NOT apply the reminder-offset cutoff — returns all window showups.
  /// IDs are deterministic and consistent with [generate] (same pact+date → same ID).
  static List<Showup> generateWindow(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) {
    // Clamp the effective range to the pact boundaries.
    final effectiveFrom = from.isBefore(pact.startDate) ? pact.startDate : from;
    final effectiveTo = to.isAfter(pact.endDate) ? pact.endDate : to;

    return _generateInRange(
      pact,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      filter: (_) => true, // no reminder-cutoff filter
    );
  }

  /// Not affected by reminderOffset, but DOES respect createdAt: slots whose window
  /// has already closed at createdAt are excluded — keeps total consistent with
  /// what can actually exist in the repository (so remaining/streak stats stay correct).
  static int countTotal(Pact pact) {
    final effectiveCreatedAt = pact.createdAt;
    if (effectiveCreatedAt == null) {
      return _countInRange(pact, from: pact.startDate, to: pact.endDate);
    }
    var count = 0;
    for (final dt in _candidates(pact)) {
      if (_isWithinRange(dt, pact.startDate, pact.endDate) && dt.add(pact.showupDuration).isAfter(effectiveCreatedAt)) {
        count++;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Core range-based generation (used by both generate() and generateWindow())
  // ---------------------------------------------------------------------------

  // Seq counter advances for every full-pact occurrence (even skipped) — keeps IDs deterministic.
  static List<Showup> _generateInRange(
    Pact pact, {
    required DateTime effectiveFrom,
    required DateTime effectiveTo,
    required bool Function(DateTime) filter,
  }) {
    var seq = 0;
    final result = <Showup>[];

    for (final scheduledAt in _candidates(pact)) {
      final currentSeq = seq++;
      if (_isWithinRange(scheduledAt, effectiveFrom, effectiveTo) && filter(scheduledAt)) {
        result.add(_showup(pact: pact, scheduledAt: scheduledAt, seq: currentSeq));
      }
    }

    return result;
  }

  static int _countInRange(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) {
    final effectiveFrom = from.isBefore(pact.startDate) ? pact.startDate : from;
    final effectiveTo = to.isAfter(pact.endDate) ? pact.endDate : to;

    if (effectiveTo.isBefore(effectiveFrom)) return 0;

    var count = 0;
    for (final dt in _candidates(pact)) {
      if (_isWithinRange(dt, effectiveFrom, effectiveTo)) count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Candidate-datetime generators (lazy, full pact range, no Showup allocation)
  // ---------------------------------------------------------------------------

  static Iterable<DateTime> _candidates(Pact pact) {
    final schedule = pact.schedule;
    return switch (schedule) {
      DailySchedule() => _candidatesDaily(pact, schedule),
      WeekdaySchedule() => _candidatesWeekday(pact, schedule),
      MonthlyByWeekdaySchedule() => _candidatesMonthlyByWeekday(pact, schedule),
      MonthlyByDateSchedule() => _candidatesMonthlyByDate(pact, schedule),
      SlotSchedule() => _candidatesSlot(pact, schedule),
    };
  }

  static Iterable<DateTime> _candidatesDaily(
    Pact pact,
    DailySchedule schedule,
  ) sync* {
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      final scheduledAt = _combine(date, schedule.timeOfDay);
      if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
        yield scheduledAt;
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
  }

  static Iterable<DateTime> _candidatesWeekday(
    Pact pact,
    WeekdaySchedule schedule,
  ) sync* {
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      for (final entry in schedule.entries) {
        if (date.weekday == entry.weekday) {
          final scheduledAt = _combine(date, entry.timeOfDay);
          if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
            yield scheduledAt;
          }
        }
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
  }

  static Iterable<DateTime> _candidatesMonthlyByWeekday(
    Pact pact,
    MonthlyByWeekdaySchedule schedule,
  ) sync* {
    for (final month in _monthsInRange(pact.startDate, pact.endDate)) {
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
          yield scheduledAt;
        }
      }
    }
  }

  static Iterable<DateTime> _candidatesMonthlyByDate(
    Pact pact,
    MonthlyByDateSchedule schedule,
  ) sync* {
    for (final month in _monthsInRange(pact.startDate, pact.endDate)) {
      for (final entry in schedule.entries) {
        final candidate = DateTime(month.year, month.month, entry.dayOfMonth);
        if (candidate.month != month.month) continue; // day doesn't exist
        final scheduledAt = _combine(candidate, entry.timeOfDay);
        if (_isWithinRange(scheduledAt, pact.startDate, pact.endDate)) {
          yield scheduledAt;
        }
      }
    }
  }

  // Day-by-day iteration ensures seq counter in _generateInRange advances identically
  // with or without a window filter — keeps IDs consistent between generate and generateWindow.
  static Iterable<DateTime> _candidatesSlot(
    Pact pact,
    SlotSchedule schedule,
  ) sync* {
    var date = pact.startDate;
    final end = pact.endDate;

    while (!date.isAfter(end)) {
      for (final slot in schedule.slots) {
        final matched = switch (slot) {
          WeeklySlot(:final weekdays, :final timeOfDay) when weekdays.contains(date.weekday) =>
            _combine(date, timeOfDay),
          MonthlySlot(:final dayOfMonth, :final timeOfDay) when date.day == dayOfMonth => _combine(date, timeOfDay),
          _ => null,
        };
        if (matched != null && _isWithinRange(matched, pact.startDate, pact.endDate)) {
          yield matched;
        }
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  // Returns null if the occurrence doesn't exist (e.g. 5th Monday in a 4-Monday month).
  static DateTime? _nthWeekdayOfMonth({
    required int year,
    required int month,
    required int weekday,
    required int occurrence,
  }) {
    var day = DateTime(year, month, 1);
    while (day.weekday != weekday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    day = day.add(Duration(days: (occurrence - 1) * 7));
    if (day.month != month) return null;
    return day;
  }

  static Iterable<DateTime> _monthsInRange(
    DateTime start,
    DateTime end,
  ) sync* {
    var year = start.year;
    var month = start.month;

    while (year < end.year || (year == end.year && month <= end.month)) {
      yield DateTime(year, month);
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  // Sub-second precision is not supported — timeOfDay must contain only h/m/s.
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

  static bool _isWithinRange(DateTime dt, DateTime start, DateTime end) {
    return !dt.isBefore(ShowupDateUtils.startOfDay(start)) && dt.isBefore(ShowupDateUtils.endOfDay(end));
  }

  static Showup _showup({
    required Pact pact,
    required DateTime scheduledAt,
    required int seq,
  }) {
    final datePart = '${scheduledAt.year}${_pad(scheduledAt.month)}${_pad(scheduledAt.day)}';
    final timePart = '${_pad(scheduledAt.hour)}${_pad(scheduledAt.minute)}${_pad(scheduledAt.second)}';
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
