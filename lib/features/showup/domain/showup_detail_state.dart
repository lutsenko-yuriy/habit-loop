import 'package:habit_loop/features/showup/domain/showup.dart';

/// Immutable state for the showup detail screen.
///
/// Follows the same pattern as [PactDetailState].
class ShowupDetailState {
  /// The loaded showup. Null until [ShowupDetailViewModel.load] completes.
  final Showup? showup;

  /// The habit name resolved from the pact associated with this showup.
  /// Null until loading completes.
  final String? habitName;

  /// True while an initial load is in progress.
  final bool isLoading;

  /// Set when the initial load fails.
  final Object? loadError;

  /// True while a mark-done, mark-failed, or save-note operation is in progress.
  final bool isSaving;

  /// Set when a mark-done or mark-failed operation fails.
  final Object? markError;

  /// Set when a save-note operation fails.
  final Object? noteError;

  /// True when the showup was automatically transitioned to [ShowupStatus.failed]
  /// on load because the current time was past `scheduledAt + duration`.
  final bool wasAutoFailed;

  const ShowupDetailState({
    this.showup,
    this.habitName,
    this.isLoading = true,
    this.loadError,
    this.isSaving = false,
    this.markError,
    this.noteError,
    this.wasAutoFailed = false,
  });

  ShowupDetailState copyWith({
    Showup? showup,
    String? habitName,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    bool? isSaving,
    Object? markError,
    bool clearMarkError = false,
    Object? noteError,
    bool clearNoteError = false,
    bool? wasAutoFailed,
  }) {
    return ShowupDetailState(
      showup: showup ?? this.showup,
      habitName: habitName ?? this.habitName,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isSaving: isSaving ?? this.isSaving,
      markError: clearMarkError ? null : (markError ?? this.markError),
      noteError: clearNoteError ? null : (noteError ?? this.noteError),
      wasAutoFailed: wasAutoFailed ?? this.wasAutoFailed,
    );
  }
}
