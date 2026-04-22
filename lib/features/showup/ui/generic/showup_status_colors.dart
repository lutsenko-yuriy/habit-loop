import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:habit_loop/features/showup/domain/showup_status.dart';

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
/// - [ShowupStatusColors.cupertino] — raw Cupertino system colours
/// - [ShowupStatusColors.material] — Material 3 [ColorScheme] slots
class ShowupStatusColors {
  final Color done;
  final Color failed;
  final Color pending;

  const ShowupStatusColors({
    required this.done,
    required this.failed,
    required this.pending,
  });

  /// Cupertino palette: green / red / grey.
  static const ShowupStatusColors cupertino = ShowupStatusColors(
    done: CupertinoColors.activeGreen,
    failed: CupertinoColors.destructiveRed,
    pending: CupertinoColors.systemGrey,
  );

  /// Material palette derived from a [ColorScheme]: secondary / error /
  /// onSurfaceVariant.
  static ShowupStatusColors material(ColorScheme cs) => ShowupStatusColors(
        done: cs.secondary,
        failed: cs.error,
        pending: cs.onSurfaceVariant,
      );

  /// Returns the color for a single showup status.
  Color forStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.done => done,
        ShowupStatus.failed => failed,
        ShowupStatus.pending => pending,
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
}
