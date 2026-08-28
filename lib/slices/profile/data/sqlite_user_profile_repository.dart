import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/domain/user/user_profile_repository.dart';
import 'package:habit_loop/domain/user/user_profile_sync_repository.dart';
import 'package:habit_loop/infrastructure/persistence/user_profile_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [UserProfileRepository] and [UserProfileSyncRepository].
///
/// Takes an open [Database] in its constructor. The database lifecycle is
/// managed by `HabitLoopDatabase`.
///
/// Backed by a **single-row** `user_profile` table (fixed `id = 'local'`) —
/// every write goes through `saveProfile`'s upsert (`ConflictAlgorithm.replace`),
/// so the single-row invariant is enforced here rather than by convention.
class SqliteUserProfileRepository implements UserProfileRepository, UserProfileSyncRepository {
  const SqliteUserProfileRepository(this._db);

  final Database _db;

  static const _table = 'user_profile';

  @override
  Future<UserProfile?> getProfile() async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [UserProfileMapper.id]);
    if (rows.isEmpty) return null;
    return UserProfileMapper.fromRow(rows.first);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _db.insert(_table, UserProfileMapper.toRow(profile), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<UserProfile?> getDirtyUserProfile() async {
    final rows = await _db.query(_table, where: 'id = ? AND dirty = ?', whereArgs: [UserProfileMapper.id, 1]);
    if (rows.isEmpty) return null;
    return UserProfileMapper.fromRow(rows.first);
  }

  @override
  Future<void> markUserProfileSynced(DateTime syncedAt) async {
    await _db.update(
      _table,
      {'dirty': 0, 'synced_at': syncedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [UserProfileMapper.id],
    );
  }

  @override
  Future<DateTime?> getUserProfileSyncedAt() async {
    final rows = await _db.query(
      _table,
      columns: ['dirty', 'synced_at'],
      where: 'id = ?',
      whereArgs: [UserProfileMapper.id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['dirty'] as int) == 1) return null; // dirty → unsync'd local changes
    final ms = row['synced_at'];
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((ms as int));
  }

  @override
  Future<void> markUserProfileDirty() async {
    await _db.update(_table, {'dirty': 1, 'synced_at': null}, where: 'id = ?', whereArgs: [UserProfileMapper.id]);
  }
}
