import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_status_colors.dart';

/// Renders the small colored dot(s) shown under a day in the dashboard
/// calendar strip. Extracted from `dashboard_page_ios.dart` and
/// `dashboard_page_android.dart` where the same layout and overflow logic
/// were duplicated with only the color source differing.
///
/// Layout rules:
/// - 0 showups → [SizedBox.shrink]
/// - 1..2 showups → one horizontal row of small dots
/// - 3 showups → two rows (2 on top, 1 on bottom)
/// - 4+ showups → a single larger "overflow" dot whose color reflects the
///   aggregate state (see [ShowupStatusColors.overflow]).
///
/// Keys:
/// - Per-showup dots use `Key('status-dot-<showup.id>')`
/// - The overflow dot uses `Key('status-dot-overflow-YYYY-MM-DD')` so keys
///   do not collide across the 7-day strip.
class ShowupStatusDots extends StatelessWidget {
  final List<Showup> showups;
  final DateTime date;
  final ShowupStatusColors colors;

  const ShowupStatusDots({
    super.key,
    required this.showups,
    required this.date,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (showups.isEmpty) return const SizedBox.shrink();

    if (showups.length >= 4) {
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
      final dateKey = _dateKey(date);
      return Container(
        key: Key('status-dot-overflow-$dateKey'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.overflow(doneCount: done, failedCount: failed, pendingCount: pending),
        ),
      );
    }

    Widget dot(Showup s) => Container(
          key: Key('status-dot-${s.id}'),
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.forStatus(s.status),
          ),
        );

    if (showups.length <= 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: showups.map(dot).toList(),
      );
    }

    // 3 showups: 2 on top row, 1 on bottom row.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [dot(showups[0]), dot(showups[1])]),
        Row(mainAxisSize: MainAxisSize.min, children: [dot(showups[2])]),
      ],
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
