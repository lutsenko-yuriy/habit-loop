class ShowupDateUtils {
  ShowupDateUtils._();

  // Calendar arithmetic (not Duration) to avoid DST edge cases.
  static DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day + 1);

  static DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
}
