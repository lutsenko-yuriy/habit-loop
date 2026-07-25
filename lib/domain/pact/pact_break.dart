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

  bool contains(DateTime scheduledAt) =>
      !scheduledAt.isBefore(startDate) && (effectiveEnd == null || !scheduledAt.isAfter(effectiveEnd!));

  bool isActiveAt(DateTime now) => contains(now);

  bool isResolved(DateTime now) => stoppedAt != null || (plannedEndDate != null && now.isAfter(plannedEndDate!));

  PactBreak stop(DateTime now) => copyWith(stoppedAt: now);

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
