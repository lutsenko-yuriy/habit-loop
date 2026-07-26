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

  const PactBreakCreationState({
    required this.startDate,
    required this.endDate,
    this.untilPactEnds = false,
    this.rationale = '',
    this.isSubmitting = false,
    this.submitError,
  });

  // The break cannot be created without a non-empty rationale (mandatory,
  // unlike the pact's optional stop reason).
  bool get canSubmit => rationale.trim().isNotEmpty && !isSubmitting;

  PactBreakCreationState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool? untilPactEnds,
    String? rationale,
    bool? isSubmitting,
    Object? submitError,
    bool clearSubmitError = false,
  }) {
    return PactBreakCreationState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      untilPactEnds: untilPactEnds ?? this.untilPactEnds,
      rationale: rationale ?? this.rationale,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}
