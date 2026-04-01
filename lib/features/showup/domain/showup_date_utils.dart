/// Shared date utilities for showup scheduling and querying.
class ShowupDateUtils {
  ShowupDateUtils._();

  /// Returns a [DateTime] representing the very end of [date]'s day
  /// (23:59:59), used for inclusive end-of-day range boundaries.
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Returns a [DateTime] representing the start of [date]'s day (00:00:00).
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
