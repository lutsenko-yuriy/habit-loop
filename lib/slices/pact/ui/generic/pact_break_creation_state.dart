class PactBreakCreationState {
  final DateTime startDate;
  final DateTime endDate;

  /// `true` when the break has no planned end date (open-ended — the user
  /// resumes whenever they choose, shown in the UI as "No end date yet").
  /// [endDate] is retained even when this is `true` so the end-date picker
  /// keeps a sensible value if the user toggles back off.
  final bool untilPactEnds;

  final String rationale;
  final bool isSubmitting;
  final Object? submitError;

  /// This pact's showups, loaded once by [PactBreakCreationViewModel.load]
  /// (HAB-215) — used only to derive [nextShowupAfterEnd]; not otherwise
  /// rendered or mutated by this screen.
  final List<DateTime> showupScheduledDates;

  const PactBreakCreationState({
    required this.startDate,
    required this.endDate,
    this.untilPactEnds = false,
    this.rationale = '',
    this.isSubmitting = false,
    this.submitError,
    this.showupScheduledDates = const [],
  });

  // The break cannot be created without a non-empty rationale (mandatory,
  // unlike the pact's optional stop reason).
  bool get canSubmit => rationale.trim().isNotEmpty && !isSubmitting;

  /// The earliest showup scheduled after this break's end, mirroring the
  /// end-of-day window `PactBreak.contains()` actually applies to
  /// `plannedEndDate` (HAB-215) — so a showup later on the picked end date
  /// is correctly treated as still inside the break, not as "next". `null`
  /// when the break is open-ended (nothing to compare against) or no such
  /// showup exists.
  DateTime? get nextShowupAfterEnd {
    if (untilPactEnds) return null;
    final endOfPickedDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    final after = showupScheduledDates.where((d) => d.isAfter(endOfPickedDay));
    if (after.isEmpty) return null;
    return after.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  PactBreakCreationState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool? untilPactEnds,
    String? rationale,
    bool? isSubmitting,
    Object? submitError,
    bool clearSubmitError = false,
    List<DateTime>? showupScheduledDates,
  }) {
    return PactBreakCreationState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      untilPactEnds: untilPactEnds ?? this.untilPactEnds,
      rationale: rationale ?? this.rationale,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      showupScheduledDates: showupScheduledDates ?? this.showupScheduledDates,
    );
  }
}
