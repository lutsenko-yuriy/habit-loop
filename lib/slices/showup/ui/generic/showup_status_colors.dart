import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ColorScheme;
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

/// Platform-agnostic showup-status color palette used by dashboard status
/// dots and showup list-tile leading icons.
///
/// Two roles:
///
/// - [forStatus] resolves a single [ShowupStatus] to a color (done / failed /
///   pending).
/// - [overflow] resolves the single colour shown for the "4+ showups" dot on
///   the calendar strip, using the same 3-colour palette:
///     * grey/onSurfaceVariant — if any showup is still pending
///     * done colour — if resolved and `done >= failed`
///     * failed colour — if resolved and `failed > done`
///
/// Two factories are provided so the call sites can keep their platform idiom
/// without duplicating the switch statement or the overflow logic:
///
/// - [ShowupStatusColors.cupertino] — Cupertino system colours resolved against
///   a [BuildContext] so dark-mode adaptation is preserved
/// - [ShowupStatusColors.material] — Material 3 [ColorScheme] slots
class ShowupStatusColors {
  final Color done;
  final Color failed;
  final Color pending;

  /// Colour used for the [ShowupUiState.waitingForStart] and
  /// [ShowupUiState.active] states so that both "attention needed" states share
  /// the same yellow/amber visual signal.
  final Color waitingForStart;

  const ShowupStatusColors({
    required this.done,
    required this.failed,
    required this.pending,
    required this.waitingForStart,
  });

  /// Returns a Cupertino palette with Cupertino system colours resolved against
  /// [context] so that dynamic light/dark adaptation is preserved.
  ///
  /// Call this inside a [StatelessWidget.build] (or any method that has a
  /// [BuildContext]) so the resolution happens against the active brightness.
  static ShowupStatusColors cupertino(BuildContext context) => ShowupStatusColors(
        done: CupertinoColors.activeGreen.resolveFrom(context),
        failed: CupertinoColors.destructiveRed.resolveFrom(context),
        pending: CupertinoColors.systemGrey.resolveFrom(context),
        waitingForStart: CupertinoColors.systemYellow.resolveFrom(context),
      );

  /// Material palette derived from a [ColorScheme]: secondary / error /
  /// onSurfaceVariant.
  static ShowupStatusColors material(ColorScheme cs) => ShowupStatusColors(
        done: cs.secondary,
        failed: cs.error,
        pending: cs.onSurfaceVariant,
        waitingForStart: Colors.amber,
      );

  /// Returns the color for a single showup status.
  Color forStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.done => done,
        ShowupStatus.failed => failed,
        ShowupStatus.pending => pending,
      };

  /// Returns the color for a time-derived [ShowupUiState].
  ///
  /// - [ShowupUiState.planned] → gray (same as unresolved pending color)
  /// - [ShowupUiState.waitingForStart] → yellow / amber
  /// - [ShowupUiState.active] → yellow / amber (active window)
  /// - [ShowupUiState.done] → green
  /// - [ShowupUiState.failed] → red
  Color forUiState(ShowupUiState state) => switch (state) {
        ShowupUiState.planned => pending,
        ShowupUiState.waitingForStart => waitingForStart,
        ShowupUiState.active => waitingForStart,
        ShowupUiState.done => done,
        ShowupUiState.failed => failed,
      };

  /// Returns the color shown for the single "overflow" dot on calendar days
  /// with 4+ showups. The caller passes pre-counted done/failed/pending
  /// totals; this keeps the resolver free of any iteration logic.
  Color overflow({
    required int doneCount,
    required int failedCount,
    required int pendingCount,
  }) {
    if (pendingCount > 0) return pending;
    return doneCount >= failedCount ? done : failed;
  }

  /// Returns the overflow dot colour given a list of time-derived [uiStates].
  ///
  /// Priority rule (first match wins):
  /// 1. Any [ShowupUiState.waitingForStart] or [ShowupUiState.active]
  ///    AND no [ShowupUiState.planned] → amber. The "AND no planned" condition
  ///    prevents the dot from jumping to amber when only some showups have
  ///    entered their active window while others are still planned ahead.
  /// 2. Any [ShowupUiState.planned] → gray (showups still upcoming)
  /// 3. All resolved: done >= failed → green; else → red
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
