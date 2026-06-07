import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ColorScheme;
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

// Status-color palette for dashboard dots and list tiles.
// Two factories: cupertino() (dark-mode-adaptive) and material() (ColorScheme slots).
class ShowupStatusColors {
  final Color done;
  final Color failed;
  final Color pending;

  final Color waitingForStart;

  const ShowupStatusColors({
    required this.done,
    required this.failed,
    required this.pending,
    required this.waitingForStart,
  });

  static ShowupStatusColors cupertino(BuildContext context) => ShowupStatusColors(
        done: CupertinoColors.activeGreen.resolveFrom(context),
        failed: CupertinoColors.destructiveRed.resolveFrom(context),
        pending: CupertinoColors.systemGrey.resolveFrom(context),
        waitingForStart: CupertinoColors.systemYellow.resolveFrom(context),
      );

  static ShowupStatusColors material(ColorScheme cs) => ShowupStatusColors(
        done: cs.secondary,
        failed: cs.error,
        pending: cs.onSurfaceVariant,
        waitingForStart: Colors.amber,
      );

  Color forStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.done => done,
        ShowupStatus.failed => failed,
        ShowupStatus.pending => pending,
      };

  Color forUiState(ShowupUiState state) => switch (state) {
        ShowupUiState.planned => pending,
        ShowupUiState.waitingForStart => waitingForStart,
        ShowupUiState.active => waitingForStart,
        ShowupUiState.done => done,
        ShowupUiState.failed => failed,
      };

  // Caller passes pre-counted totals; resolver stays free of iteration logic.
  Color overflow({
    required int doneCount,
    required int failedCount,
    required int pendingCount,
  }) {
    if (pendingCount > 0) return pending;
    return doneCount >= failedCount ? done : failed;
  }

  // Priority: active (no planned ahead) → amber; any planned → gray; resolved → green/red.
  // "AND no planned" prevents premature amber when only some showups entered their window.
  Color overflowForUiState(List<ShowupUiState> uiStates) {
    var activeCount = 0, plannedCount = 0, doneCount = 0, failedCount = 0;
    for (final s in uiStates) {
      switch (s) {
        case ShowupUiState.waitingForStart:
        case ShowupUiState.active:
          activeCount++;
        case ShowupUiState.planned:
          plannedCount++;
        case ShowupUiState.done:
          doneCount++;
        case ShowupUiState.failed:
          failedCount++;
      }
    }
    if (activeCount > 0 && plannedCount == 0) return waitingForStart;
    if (plannedCount > 0) return pending;
    return doneCount >= failedCount ? done : failed;
  }
}
