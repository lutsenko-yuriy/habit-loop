import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Statistics for a pact based on its [Showup] instances.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactStats &&
          showupsDone == other.showupsDone &&
          showupsFailed == other.showupsFailed &&
          showupsRemaining == other.showupsRemaining &&
          totalShowups == other.totalShowups &&
          currentStreak == other.currentStreak &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
        showupsDone,
        showupsFailed,
        showupsRemaining,
        totalShowups,
        currentStreak,
        startDate,
        endDate,
      );

  PactStats copyWith({
    int? showupsDone,
    int? showupsFailed,
    int? showupsRemaining,
    int? totalShowups,
    int? currentStreak,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return PactStats(
      showupsDone: showupsDone ?? this.showupsDone,
      showupsFailed: showupsFailed ?? this.showupsFailed,
      showupsRemaining: showupsRemaining ?? this.showupsRemaining,
      totalShowups: totalShowups ?? this.totalShowups,
      currentStreak: currentStreak ?? this.currentStreak,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Computes statistics for a pact from its associated [showups].
  ///
  /// When [totalShowups] is provided it overrides the list-length derivation:
  /// - [PactStats.totalShowups] is set to [totalShowups].
  /// - [PactStats.showupsRemaining] is computed as
  ///   `totalShowups - done - failed`, which accounts for showups outside
  ///   the persisted window (e.g. when only an initial rolling window has
  ///   been persisted rather than the full pact duration).
  ///
  /// When [totalShowups] is omitted, both fields are derived from [showups]:
  /// - [PactStats.totalShowups] equals `showups.length`.
  /// - [PactStats.showupsRemaining] equals the number of pending showups.
  factory PactStats.compute({
    required DateTime startDate,
    required DateTime endDate,
    required List<Showup> showups,
    int? totalShowups,
  }) {
    final done = showups.where((s) => s.status == ShowupStatus.done).length;
    final failed = showups.where((s) => s.status == ShowupStatus.failed).length;

    final effectiveTotal = totalShowups ?? showups.length;
    final remaining = totalShowups != null
        ? (totalShowups - done - failed).clamp(0, totalShowups)
        : showups.where((s) => s.status == ShowupStatus.pending).length;

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
      totalShowups: effectiveTotal,
      currentStreak: streak,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
