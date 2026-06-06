import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

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

  /// [totalShowups] overrides list-length derivation: remaining = totalShowups - done - failed
  /// (accounts for showups outside the persisted window). Omit to derive both from the list.
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

    // Pending showups are excluded — they haven't been resolved yet.
    final resolved = showups.where((s) => s.status != ShowupStatus.pending).toList()
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
