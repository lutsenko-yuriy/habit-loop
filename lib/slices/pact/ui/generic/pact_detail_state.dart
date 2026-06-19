import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';

class PactDetailState {
  final Pact? pact;
  final PactStats? stats;
  final bool isLoading;
  final Object? loadError;
  final bool isStopping;
  final Object? stopError;
  final bool isSavingNote;
  final Object? noteError;
  final bool isArchiving;
  final Object? archiveError;

  const PactDetailState({
    this.pact,
    this.stats,
    this.isLoading = true,
    this.loadError,
    this.isStopping = false,
    this.stopError,
    this.isSavingNote = false,
    this.noteError,
    this.isArchiving = false,
    this.archiveError,
  });

  PactDetailState copyWith({
    Pact? pact,
    PactStats? stats,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    bool? isStopping,
    Object? stopError,
    bool clearStopError = false,
    bool? isSavingNote,
    Object? noteError,
    bool clearNoteError = false,
    bool? isArchiving,
    Object? archiveError,
    bool clearArchiveError = false,
  }) {
    return PactDetailState(
      pact: pact ?? this.pact,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isStopping: isStopping ?? this.isStopping,
      stopError: clearStopError ? null : (stopError ?? this.stopError),
      isSavingNote: isSavingNote ?? this.isSavingNote,
      noteError: clearNoteError ? null : (noteError ?? this.noteError),
      isArchiving: isArchiving ?? this.isArchiving,
      archiveError: clearArchiveError ? null : (archiveError ?? this.archiveError),
    );
  }
}
