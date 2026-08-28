import 'package:habit_loop/domain/user/user_profile.dart';

/// Maps [UserProfile] domain objects to and from SQLite row maps.
///
/// The canonical column-to-field mapping is defined by [toRow] and [fromRow].
/// Schema DDL lives in `HabitLoopDatabase.runMigrations`.
///
/// `user_profile` is a single-row table (fixed `id = 'local'`) — [toRow]
/// always writes that fixed id; [fromRow] ignores the row's `id` column
/// since it carries no domain meaning.
abstract final class UserProfileMapper {
  /// The fixed single-row id — the one-row invariant is enforced by the
  /// repository (upsert via `ConflictAlgorithm.replace`), not by this mapper.
  static const id = 'local';

  /// Converts [profile] to a column map ready for SQLite insertion or update.
  static Map<String, dynamic> toRow(UserProfile profile) {
    return {
      'id': id,
      'display_name': profile.displayName,
      'updated_at': profile.updatedAt.millisecondsSinceEpoch,
      // Every insert/update starts dirty=1 — queued for the first sync flush.
      'dirty': 1,
      'synced_at': null,
    };
  }

  /// Reconstructs a [UserProfile] from a SQLite row map.
  ///
  /// Dates are restored as **local-time** [DateTime]s, matching the
  /// local-time convention used by `PactBreakMapper`.
  static UserProfile fromRow(Map<String, dynamic> row) {
    return UserProfile(
      displayName: row['display_name'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as num).toInt()),
      // dirty and synced_at live only in the sync layer — not on the domain model.
    );
  }
}
