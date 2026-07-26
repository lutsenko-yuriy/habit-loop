import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

// Calendar-strip dot cluster. Layout: 0=shrink, 1-2=row, 3=2+1 rows, 4+=overflow dot.
// Keys: status-dot-<showup.id>, status-dot-overflow-YYYY-MM-DD.
class ShowupStatusDots extends StatelessWidget {
  final List<Showup> showups;
  final DateTime date;
  final ShowupStatusColors colors;

  // When provided and length matches showups, uses forUiState (surfaces amber waitingForStart signal).
  final List<ShowupUiState>? uiStates;

  const ShowupStatusDots({
    super.key,
    required this.showups,
    required this.date,
    required this.colors,
    this.uiStates,
  });

  @override
  Widget build(BuildContext context) {
    if (showups.isEmpty) return const SizedBox.shrink();

    final useUiStates = uiStates != null && uiStates!.length == showups.length;

    if (showups.length >= 4) {
      final overflowIsOnBreak = useUiStates && uiStates!.any((s) => s == ShowupUiState.onBreak);
      final overflowColor = useUiStates
          ? colors.overflowForUiState(uiStates!)
          : () {
              var done = 0, failed = 0, pending = 0;
              for (final s in showups) {
                switch (s.status) {
                  case ShowupStatus.done:
                    done++;
                  case ShowupStatus.failed:
                    failed++;
                  case ShowupStatus.pending:
                    pending++;
                }
              }
              return colors.overflow(doneCount: done, failedCount: failed, pendingCount: pending);
            }();
      return _dotCircle(
        key: Key('status-dot-overflow-${_dateKey(date)}'),
        size: 10,
        color: overflowColor,
        showPauseGlyph: overflowIsOnBreak,
      );
    }

    Widget dot(Showup s, int index) {
      final isOnBreak = useUiStates && uiStates![index] == ShowupUiState.onBreak;
      final color = useUiStates ? colors.forUiState(uiStates![index]) : colors.forStatus(s.status);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: _dotCircle(
          key: Key('status-dot-${s.id}'),
          size: 6,
          color: color,
          showPauseGlyph: isOnBreak,
        ),
      );
    }

    if (showups.length <= 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < showups.length; i++) dot(showups[i], i)],
      );
    }

    // 3 showups: 2 on top row, 1 on bottom row.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [dot(showups[0], 0), dot(showups[1], 1)]),
        Row(mainAxisSize: MainAxisSize.min, children: [dot(showups[2], 2)]),
      ],
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // A pause glyph on top of the colored circle marks the on-break state
  // (HAB-195); other states stay glyph-free, matching the pre-existing look.
  static Widget _dotCircle({
    required Key key,
    required double size,
    required Color color,
    required bool showPauseGlyph,
  }) {
    return Container(
      key: key,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: showPauseGlyph ? Icon(Icons.pause, size: size * 0.75, color: const Color(0xFFFFFFFF)) : null,
    );
  }
}
