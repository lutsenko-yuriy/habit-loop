import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite [Database] lifecycle for the Habit Loop app.
///
/// Use [HabitLoopDatabase.instance] to obtain the singleton in production code.
/// In tests, call [HabitLoopDatabase.runMigrations] directly with a
/// [databaseFactoryFfi]-opened in-memory database — never use the singleton in
/// tests (it would open a file-backed database on the test host).
///
/// Schema version: 1.
class HabitLoopDatabase {
  HabitLoopDatabase._();

  /// The production singleton. Do not use in tests.
  static final HabitLoopDatabase instance = HabitLoopDatabase._();

  // Stores the in-flight or resolved Future<Database> rather than the resolved
  // Database itself.  The ??= assignment is synchronous (no await before it),
  // so concurrent callers all receive the *same* Future and only one _open()
  // call is ever initiated — eliminating the double-open race.
  Future<Database>? _dbFuture;

  /// Returns the open [Database], opening it on first access.
  ///
  /// Multiple concurrent callers are safe: the `??=` assignment is synchronous
  /// so only one [_open] call is ever scheduled, regardless of how many
  /// `await database` calls race at cold-start.
  Future<Database> get database => _dbFuture ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'habit_loop.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: runMigrations,
    );
  }

  /// Closes the underlying database connection.
  ///
  /// After calling this, the next access to [database] will reopen the file.
  Future<void> close() async {
    final db = await _dbFuture;
    await db?.close();
    _dbFuture = null;
  }

  // ---------------------------------------------------------------------------
  // Migration callbacks (public so tests can invoke them directly)
  // ---------------------------------------------------------------------------

  /// Schema v1 DDL — creates both tables and their indexes.
  ///
  /// Exposed as a public static so unit tests can pass it directly to
  /// [OpenDatabaseOptions.onCreate] with a [databaseFactoryFfi] in-memory
  /// database, without going through the file-backed singleton.
  static Future<void> runMigrations(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pacts (
        id                   TEXT    NOT NULL PRIMARY KEY,
        habit_name           TEXT    NOT NULL,
        start_date           INTEGER NOT NULL,
        scheduled_end_date   INTEGER NOT NULL,
        actual_end_date      INTEGER NOT NULL,
        showup_duration      INTEGER NOT NULL,
        schedule             TEXT    NOT NULL,
        status               TEXT    NOT NULL,
        reminder_offset      INTEGER,
        stop_reason          TEXT,
        total_showups        INTEGER,
        created_at           INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE showups (
        id           TEXT    NOT NULL PRIMARY KEY,
        pact_id      TEXT    NOT NULL,
        scheduled_at INTEGER NOT NULL,
        duration     INTEGER NOT NULL,
        status       TEXT    NOT NULL,
        note         TEXT,
        FOREIGN KEY (pact_id) REFERENCES pacts(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_showups_pact_id ON showups (pact_id)');
    await db.execute('CREATE INDEX idx_showups_scheduled_at ON showups (scheduled_at)');
  }

  // ---------------------------------------------------------------------------
  // Testing helpers
  // ---------------------------------------------------------------------------

  /// Opens a fresh in-memory database with the v1 schema applied.
  ///
  /// Intended for use in unit tests only. The caller owns the returned
  /// [Database] and is responsible for closing it.
  @visibleForTesting
  static Future<Database> openForTesting() async {
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: runMigrations,
      ),
    );
  }
}
