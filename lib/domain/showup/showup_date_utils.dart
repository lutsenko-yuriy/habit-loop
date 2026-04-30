/// Shared date utilities for showup scheduling and querying.
class ShowupDateUtils {
  ShowupDateUtils._();

  /// Returns the exclusive upper-bound for [date]'s day — the start of the
  /// following day (00:00:00). Use with [DateTime.isBefore] for
  /// end-of-day range checks. Calendar arithmetic is used instead of
  /// [Duration] addition to avoid DST edge cases.
  static DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day + 1);

  /// Returns a [DateTime] representing the start of [date]'s day (00:00:00).
  static DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
}
