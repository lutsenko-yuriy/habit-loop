class PactBreak {
  final String id;
  final String pactId;
  final DateTime startDate;
  final String rationale;

  // null = "until pact ends".
  final DateTime? plannedEndDate;

  final DateTime? createdAt;

  // null = not stopped; once set, fixes effectiveEnd permanently (mirrors Pact.stoppedAt).
  final DateTime? stoppedAt;

  const PactBreak({
    required this.id,
    required this.pactId,
    required this.startDate,
    required this.rationale,
    this.plannedEndDate,
    this.createdAt,
    this.stoppedAt,
  });

  DateTime? get effectiveEnd => stoppedAt ?? plannedEndDate;

  // plannedEndDate is a picked calendar date (HAB-215), not a precise instant —
  // it must cover the whole day it names, or a showup later that same day would
  // read as already past the break. stoppedAt, by contrast, is the exact instant
  // "Resume pact" was tapped (or an already-elapsed plannedEndDate clamped to
  // itself, below) and is never widened. Applied at read time (contains/isResolved)
  // rather than at write time, so it also self-heals breaks already persisted with
  // a midnight plannedEndDate from before this fix.
  static DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  bool contains(DateTime scheduledAt) {
    if (scheduledAt.isBefore(startDate)) return false;
    if (stoppedAt != null) return !scheduledAt.isAfter(stoppedAt!);
    final planned = plannedEndDate;
    return planned == null || !scheduledAt.isAfter(_endOfDay(planned));
  }

  bool isActiveAt(DateTime now) => contains(now);

  bool isResolved(DateTime now) {
    final plannedEnd = plannedEndDate;
    return stoppedAt != null || (plannedEnd != null && now.isAfter(_endOfDay(plannedEnd)));
  }

  // No-op once already stopped, and clamps to plannedEndDate's end-of-day —
  // stopping an already-elapsed fixed-end break must not extend/revive its window.
  PactBreak stop(DateTime now) {
    if (stoppedAt != null) return this;
    final plannedEnd = plannedEndDate;
    final plannedEndOfDay = plannedEnd == null ? null : _endOfDay(plannedEnd);
    final clamped = plannedEndOfDay != null && now.isAfter(plannedEndOfDay) ? plannedEndOfDay : now;
    return copyWith(stoppedAt: clamped);
  }

  // id, pactId, and startDate are immutable — they form the identity of a break.
  PactBreak copyWith({
    String? rationale,
    DateTime? plannedEndDate,
    DateTime? stoppedAt,
    bool clearPlannedEndDate = false,
    bool clearStoppedAt = false,
  }) {
    return PactBreak(
      id: id,
      pactId: pactId,
      startDate: startDate,
      rationale: rationale ?? this.rationale,
      plannedEndDate: clearPlannedEndDate ? null : (plannedEndDate ?? this.plannedEndDate),
      createdAt: createdAt,
      stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactBreak &&
          id == other.id &&
          pactId == other.pactId &&
          startDate == other.startDate &&
          rationale == other.rationale &&
          plannedEndDate == other.plannedEndDate &&
          createdAt == other.createdAt &&
          stoppedAt == other.stoppedAt;

  @override
  int get hashCode => Object.hash(id, pactId, startDate, rationale, plannedEndDate, createdAt, stoppedAt);
}
