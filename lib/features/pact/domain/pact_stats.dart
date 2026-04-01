import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Computed statistics for a [Pact] based on its [Showup] instances.
class PactStats {
  final int showupsDone;
  final int showupsFailed;
  final int showupsRemaining;
  final int totalShowups;
  final int currentStreak;
  final DateTime startDate;
  final DateTime endDate;

  const PactStats({
    required this.showupsDone,
    required this.showupsFailed,
    required this.showupsRemaining,
    required this.totalShowups,
    required this.currentStreak,
    required this.startDate,
    required this.endDate,
  });

  /// Computes statistics for [pact] from its associated [showups].
  factory PactStats.compute({
    required Pact pact,
    required List<Showup> showups,
  }) {
    final done = showups.where((s) => s.status == ShowupStatus.done).length;
    final failed =
        showups.where((s) => s.status == ShowupStatus.failed).length;
    final remaining =
        showups.where((s) => s.status == ShowupStatus.pending).length;

    // Current streak: count consecutive done showups from the most recent
    // resolved (non-pending) showup backwards. Pending showups are excluded
    // from streak calculation — they have not been resolved yet and do not
    // break or extend the streak.
    // `..sort(...)` is Dart's cascade operator: it calls sort() on the list
    // and returns the list itself (not the void return of sort), so we can
    // assign the sorted list in one expression.
    final resolved = showups
        .where((s) => s.status != ShowupStatus.pending)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    var streak = 0;
    for (var i = resolved.length - 1; i >= 0; i--) {
      if (resolved[i].status == ShowupStatus.done) {
        streak++;
      } else {
        break;
      }
    }

    return PactStats(
      showupsDone: done,
      showupsFailed: failed,
      showupsRemaining: remaining,
      totalShowups: showups.length,
      currentStreak: streak,
      startDate: pact.startDate,
      endDate: pact.endDate,
    );
  }
}
