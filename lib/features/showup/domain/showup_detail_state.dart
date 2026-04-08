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

  /// Set when a save operation (mark or note) fails.
  final Object? saveError;

  /// True when the showup was automatically transitioned to [ShowupStatus.failed]
  /// on load because the current time was past `scheduledAt + duration`.
  final bool wasAutoFailed;

  const ShowupDetailState({
    this.showup,
    this.habitName,
    this.isLoading = true,
    this.loadError,
    this.isSaving = false,
    this.saveError,
    this.wasAutoFailed = false,
  });

  ShowupDetailState copyWith({
    Showup? showup,
    String? habitName,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    bool? isSaving,
    Object? saveError,
    bool clearSaveError = false,
    bool? wasAutoFailed,
  }) {
    return ShowupDetailState(
      showup: showup ?? this.showup,
      habitName: habitName ?? this.habitName,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      wasAutoFailed: wasAutoFailed ?? this.wasAutoFailed,
    );
  }
}
