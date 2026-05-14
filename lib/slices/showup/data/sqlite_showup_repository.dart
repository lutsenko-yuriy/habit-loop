import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_date_utils.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [ShowupRepository] and [ShowupSyncRepository].
///
/// Takes an open [Database] in its constructor. The database lifecycle is
/// managed by [HabitLoopDatabase].
///
/// All [DateTime] fields are stored as epoch milliseconds and reconstructed as
/// **local-time** values via [ShowupMapper], matching the local-time values
/// produced by [ShowupGenerator].
///
/// The `dirty` and `synced_at` columns are managed internally by this class
/// and are never exposed through [ShowupRepository]. Only [ShowupSyncRepository]
/// methods touch them.
class SqliteShowupRepository implements ShowupRepository, ShowupSyncRepository {
  const SqliteShowupRepository(this._db);

  final Database _db;

  static const _table = 'showups';

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<Showup?> getShowupById(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ShowupMapper.fromRow(rows.first);
  }

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    final rows = await _db.query(_table, where: 'pact_id = ?', whereArgs: [pactId]);
    return rows.map(ShowupMapper.fromRow).toList();
  }

  @override
  Future<List<Showup>> getShowupsForDate(DateTime date) async {
    final startMs = ShowupDateUtils.startOfDay(date).millisecondsSinceEpoch;
    final endMs = ShowupDateUtils.endOfDay(date).millisecondsSinceEpoch;
    final rows = await _db.query(
      _table,
      where: 'scheduled_at >= ? AND scheduled_at < ?',
      whereArgs: [startMs, endMs],
    );
    return rows.map(ShowupMapper.fromRow).toList();
  }

  @override
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end) async {
    final startMs = ShowupDateUtils.startOfDay(start).millisecondsSinceEpoch;
    final endMs = ShowupDateUtils.endOfDay(end).millisecondsSinceEpoch;
    final rows = await _db.query(
      _table,
      where: 'scheduled_at >= ? AND scheduled_at < ?',
      whereArgs: [startMs, endMs],
    );
    return rows.map(ShowupMapper.fromRow).toList();
  }

  @override
  Future<int> countShowupsForPact(String pactId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_table WHERE pact_id = ?',
      [pactId],
    );
    return (result.first['cnt'] as num).toInt();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveShowup(Showup showup) async {
    final existing = await getShowupById(showup.id);
    if (existing != null) {
      throw ArgumentError('Showup with id "${showup.id}" already exists.');
    }
    await _db.insert(_table, ShowupMapper.toRow(showup));
  }

  /// Persists multiple showups, skipping any whose ids already exist.
  ///
  /// The entire batch is wrapped in a transaction so either all new showups are
  /// written or none are (atomic). Accumulators are declared *inside* the
  /// transaction closure so that sqflite transaction retries (on SQLITE_BUSY)
  /// do not produce duplicate entries in the result.
  @override
  Future<SaveShowupsResult> saveShowups(List<Showup> showups) async {
    if (showups.isEmpty) {
      return SaveShowupsResult(savedCount: 0, skippedIds: []);
    }

    final (savedCount, skippedIds) = await _db.transaction<(int, List<String>)>((txn) async {
      // Collect existing ids in one query to minimise round-trips.
      final ids = showups.map((s) => s.id).toList();
      final placeholders = List.filled(ids.length, '?').join(', ');
      final existingRows = await txn.rawQuery(
        'SELECT id FROM $_table WHERE id IN ($placeholders)',
        ids,
      );
      final existingIds = existingRows.map((r) => r['id'] as String).toSet();

      final localSkipped = <String>[];
      var localSaved = 0;
      for (final showup in showups) {
        if (existingIds.contains(showup.id)) {
          localSkipped.add(showup.id);
        } else {
          await txn.insert(_table, ShowupMapper.toRow(showup));
          localSaved++;
        }
      }
      return (localSaved, localSkipped);
    });

    return SaveShowupsResult(savedCount: savedCount, skippedIds: skippedIds);
  }

  @override
  Future<void> updateShowup(Showup showup) async {
    final existing = await getShowupById(showup.id);
    if (existing == null) {
      throw ArgumentError('Showup with id "${showup.id}" not found.');
    }
    await _db.insert(_table, ShowupMapper.toRow(showup), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteShowupsForPact(String pactId) async {
    await _db.delete(_table, where: 'pact_id = ?', whereArgs: [pactId]);
  }

  // ---------------------------------------------------------------------------
  // ShowupSyncRepository
  // ---------------------------------------------------------------------------

  @override
  Future<List<Showup>> getDirtyShowups() async {
    final rows = await _db.query(_table, where: 'dirty = ?', whereArgs: [1]);
    return rows.map(ShowupMapper.fromRow).toList();
  }

  @override
  Future<void> markShowupSynced(String showupId, DateTime syncedAt) async {
    await _db.update(
      _table,
      {'dirty': 0, 'synced_at': syncedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [showupId],
    );
  }

  @override
  Future<DateTime?> getShowupSyncedAt(String showupId) async {
    final rows = await _db.query(
      _table,
      columns: ['dirty', 'synced_at'],
      where: 'id = ?',
      whereArgs: [showupId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['dirty'] as int) == 1) return null; // dirty → unsync'd local changes
    final ms = row['synced_at'];
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((ms as int));
  }
}
