import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

/// Immutable state for the showup detail screen.
///
/// Follows the same pattern as [PactDetailState].
class ShowupDetailState {
  /// The loaded showup. Null until [ShowupDetailViewModel.load] completes.
  final Showup? showup;

  /// The habit name resolved from the pact associated with this showup.
  /// Null until loading completes.
  final String? habitName;

  /// The reminder offset from the pact associated with this showup. Used to
  /// derive [ShowupUiState] so the detail screen can display time-sensitive
  /// labels ("Planned", "Waiting for start") instead of the raw domain status.
  /// Null when the pact has no reminder set or the pact could not be found.
  final Duration? reminderOffset;

  /// The time-derived UI state for the loaded showup. Derived in
  /// [ShowupDetailViewModel.load] using [showupDetailNowProvider] so the
  /// badge always reflects the clock at the moment the screen opened, not
  /// the widget-build time. Defaults to [ShowupUiState.planned] until loading
  /// completes.
  final ShowupUiState uiState;

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

  /// True when [ShowupDetailViewModel.load] could not find the showup in the
  /// repository. This is a distinct case from a generic load failure — it
  /// typically means the showup was deleted or the notification payload is
  /// stale. The UI layer renders a localised "showup no longer available"
  /// message rather than the raw error string.
  final bool isShowupNotFound;

  const ShowupDetailState({
    this.showup,
    this.habitName,
    this.reminderOffset,
    this.uiState = ShowupUiState.planned,
    this.isLoading = true,
    this.loadError,
    this.isSaving = false,
    this.markError,
    this.noteError,
    this.wasAutoFailed = false,
    this.isShowupNotFound = false,
  });

  ShowupDetailState copyWith({
    Showup? showup,
    String? habitName,
    Duration? reminderOffset,
    bool clearReminderOffset = false,
    ShowupUiState? uiState,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    bool? isSaving,
    Object? markError,
    bool clearMarkError = false,
    Object? noteError,
    bool clearNoteError = false,
    bool? wasAutoFailed,
    bool? isShowupNotFound,
  }) {
    return ShowupDetailState(
      showup: showup ?? this.showup,
      habitName: habitName ?? this.habitName,
      reminderOffset: clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      uiState: uiState ?? this.uiState,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isSaving: isSaving ?? this.isSaving,
      markError: clearMarkError ? null : (markError ?? this.markError),
      noteError: clearNoteError ? null : (noteError ?? this.noteError),
      wasAutoFailed: wasAutoFailed ?? this.wasAutoFailed,
      isShowupNotFound: isShowupNotFound ?? this.isShowupNotFound,
    );
  }
}
