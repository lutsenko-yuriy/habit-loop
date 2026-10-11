import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';

enum PactChecklistSectionError {
  /// Checklister has no checklists to pick from.
  noChecklists,

  /// Checklister could not be opened.
  couldNotOpen,
}

class PactChecklistSectionState {
  const PactChecklistSectionState({this.isLoaded = false, this.link, this.error});

  /// `false` until the link has been read once.
  final bool isLoaded;
  final PactChecklistLink? link;
  final PactChecklistSectionError? error;

  PactChecklistSectionState copyWith({
    bool? isLoaded,
    PactChecklistLink? link,
    bool clearLink = false,
    PactChecklistSectionError? error,
    bool clearError = false,
  }) =>
      PactChecklistSectionState(
        isLoaded: isLoaded ?? this.isLoaded,
        link: clearLink ? null : (link ?? this.link),
        error: clearError ? null : (error ?? this.error),
      );
}
