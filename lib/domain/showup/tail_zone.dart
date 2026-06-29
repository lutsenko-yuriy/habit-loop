/// Shared tail-zone predicate used by the timeline grouper and redemption eligibility.
///
/// The tail zone is defined as: calendar days in [now - days, ∞).
/// Both call sites must use this helper so they cannot diverge.
abstract final class TailZone {
  /// Returns true if [scheduledAt] falls within the tail zone anchored on [now].
  ///
  /// [days] is the RC-configured window (e.g. `pact_timeline_no_grouping_tail_period_in_days`).
  /// The cutoff is calendar-day-based: time-of-day on [now] does not affect the boundary.
  static bool contains({
    required DateTime scheduledAt,
    required DateTime now,
    required int days,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(Duration(days: days));
    return !scheduledAt.isBefore(cutoff);
  }
}
