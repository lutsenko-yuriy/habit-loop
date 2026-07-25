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

  bool contains(DateTime scheduledAt) {
    final end = effectiveEnd;
    return !scheduledAt.isBefore(startDate) && (end == null || !scheduledAt.isAfter(end));
  }

  bool isActiveAt(DateTime now) => contains(now);

  bool isResolved(DateTime now) {
    final plannedEnd = plannedEndDate;
    return stoppedAt != null || (plannedEnd != null && now.isAfter(plannedEnd));
  }

  // No-op once already stopped, and clamps to plannedEndDate — stopping an
  // already-elapsed fixed-end break must not extend/revive its window.
  PactBreak stop(DateTime now) {
    if (stoppedAt != null) return this;
    final plannedEnd = plannedEndDate;
    final clamped = plannedEnd != null && now.isAfter(plannedEnd) ? plannedEnd : now;
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
