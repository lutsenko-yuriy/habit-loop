import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

class ShowupDetailState {
  final Showup? showup;
  final String? habitName;
  // Used to derive ShowupUiState for time-sensitive labels ("Planned", "Waiting for start").
  final Duration? reminderOffset;
  // Defaults to planned until loading completes.
  final ShowupUiState uiState;
  final bool isLoading;
  final Object? loadError;
  final bool isSaving;
  final Object? markError;
  final Object? noteError;
  final bool wasAutoFailed;
  // Distinct from generic load failure — stale notification payload or deleted showup.
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
