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
      return Container(
        key: Key('status-dot-overflow-${_dateKey(date)}'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: overflowColor),
      );
    }

    Widget dot(Showup s, int index) {
      final color = useUiStates ? colors.forUiState(uiStates![index]) : colors.forStatus(s.status);
      return Container(
        key: Key('status-dot-${s.id}'),
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
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
}
