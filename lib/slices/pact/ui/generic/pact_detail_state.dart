import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
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

  /// The single unresolved break for this pact, if any (HAB-195). `null`
  /// means no break is currently active or scheduled, so a new one may be
  /// started. Intentionally includes a break that hasn't started yet —
  /// this still gates "Take a Break" and `stopBreak`'s cancel-ahead-of-time
  /// support. Use [isBreakActiveNow] for display purposes instead.
  final PactBreak? activeBreak;

  /// Whether [activeBreak] has actually started (`now` falls within its
  /// window) as opposed to being merely scheduled — the signal the break
  /// banner should render on. `false` whenever [activeBreak] is null (HAB-201).
  final bool isBreakActiveNow;

  final bool isStoppingBreak;
  final Object? stopBreakError;

  /// The predecessor pact this pact was chained from (HAB-202), if any —
  /// i.e. the pact referenced by `pact.predecessorPactId`. `null` if this
  /// pact has no predecessor.
  final Pact? predecessorPact;

  /// The successor pact chained from this pact (HAB-202), if any — i.e. the
  /// pact whose `predecessorPactId` equals this pact's id. `null` if no
  /// successor exists yet.
  final Pact? successorPact;

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
    this.activeBreak,
    this.isBreakActiveNow = false,
    this.isStoppingBreak = false,
    this.stopBreakError,
    this.predecessorPact,
    this.successorPact,
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
    PactBreak? activeBreak,
    bool clearActiveBreak = false,
    bool? isBreakActiveNow,
    bool? isStoppingBreak,
    Object? stopBreakError,
    bool clearStopBreakError = false,
    Pact? predecessorPact,
    bool clearPredecessorPact = false,
    Pact? successorPact,
    bool clearSuccessorPact = false,
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
      activeBreak: clearActiveBreak ? null : (activeBreak ?? this.activeBreak),
      isBreakActiveNow: isBreakActiveNow ?? this.isBreakActiveNow,
      isStoppingBreak: isStoppingBreak ?? this.isStoppingBreak,
      stopBreakError: clearStopBreakError ? null : (stopBreakError ?? this.stopBreakError),
      predecessorPact: clearPredecessorPact ? null : (predecessorPact ?? this.predecessorPact),
      successorPact: clearSuccessorPact ? null : (successorPact ?? this.successorPact),
    );
  }
}
