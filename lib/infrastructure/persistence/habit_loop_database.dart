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
/// Schema version: 7.
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
      version: 7,
      onConfigure: (db) async {
        // Enable WAL journal mode so concurrent readers (main isolate) and the
        // background notification handler isolate can operate simultaneously
        // without producing SQLITE_BUSY errors. WAL allows one writer and
        // multiple readers at the same time.
        //
        // Use rawQuery (not execute) because PRAGMA journal_mode=WAL returns a
        // result row — on Android, execSQL() (which backs execute()) throws for
        // statements that return results.  We ignore the returned mode name;
        // if WAL is unavailable the database silently falls back to the default
        // journal mode and the app continues to work correctly.
        try {
          await db.rawQuery('PRAGMA journal_mode=WAL');
        } catch (_) {
          // WAL mode is best-effort; a failure must not prevent the database
          // from opening.  The main risk without WAL is SQLITE_BUSY when the
          // background notification isolate and the main isolate write
          // simultaneously — acceptable given the low concurrency window.
        }
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: runMigrations,
      onUpgrade: runUpgradeMigrations,
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

  /// Current full schema DDL — creates all tables and their indexes.
  ///
  /// Used as `onCreate` for fresh installs, so it always reflects the latest
  /// schema version rather than just v1; existing installs instead go through
  /// [runUpgradeMigrations].
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
        created_at           INTEGER,
        dirty                INTEGER NOT NULL DEFAULT 1,
        synced_at            INTEGER,
        archived             INTEGER NOT NULL DEFAULT 0,
        predecessor_pact_id  TEXT
      )
    ''');
    // Enforces "at most one successor per pact" (HAB-202) — no self-referential
    // FK is declared on predecessor_pact_id, so a chained pact synced down from
    // Firestore before its predecessor arrives locally can never trigger an FK
    // violation; validity of the reference itself is enforced at the app layer.
    await db.execute(
      'CREATE UNIQUE INDEX idx_pacts_predecessor_pact_id ON pacts (predecessor_pact_id) '
      'WHERE predecessor_pact_id IS NOT NULL',
    );
    await db.execute('''
      CREATE TABLE showups (
        id           TEXT    NOT NULL PRIMARY KEY,
        pact_id      TEXT    NOT NULL,
        scheduled_at INTEGER NOT NULL,
        duration     INTEGER NOT NULL,
        status       TEXT    NOT NULL,
        note         TEXT,
        redeemable   INTEGER NOT NULL DEFAULT 1,
        dirty        INTEGER NOT NULL DEFAULT 1,
        synced_at    INTEGER,
        FOREIGN KEY (pact_id) REFERENCES pacts(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_showups_pact_id ON showups (pact_id)');
    await db.execute('CREATE INDEX idx_showups_scheduled_at ON showups (scheduled_at)');
    await db.execute('''
      CREATE TABLE pact_breaks (
        id                TEXT    NOT NULL PRIMARY KEY,
        pact_id           TEXT    NOT NULL,
        start_date        INTEGER NOT NULL,
        rationale         TEXT    NOT NULL,
        planned_end_date  INTEGER,
        created_at        INTEGER,
        stopped_at        INTEGER,
        dirty             INTEGER NOT NULL DEFAULT 1,
        synced_at         INTEGER,
        FOREIGN KEY (pact_id) REFERENCES pacts(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_pact_breaks_pact_id ON pact_breaks (pact_id)');
    await db.execute('''
      CREATE TABLE user_profile (
        id            TEXT    NOT NULL PRIMARY KEY,
        display_name  TEXT,
        updated_at    INTEGER NOT NULL,
        dirty         INTEGER NOT NULL DEFAULT 0,
        synced_at     INTEGER
      )
    ''');
  }

  /// Incremental schema upgrades from [oldVersion] to [newVersion].
  ///
  /// Exposed as a public static so tests can verify the upgrade path without
  /// going through the file-backed singleton.
  static Future<void> runUpgradeMigrations(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2 adds dirty/synced_at columns for Firestore sync tracking.
      // DEFAULT 1 means all existing rows are immediately queued for first sync.
      await db.execute('ALTER TABLE pacts ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE pacts ADD COLUMN synced_at INTEGER');
      await db.execute('ALTER TABLE showups ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE showups ADD COLUMN synced_at INTEGER');
    }
    if (oldVersion < 3) {
      // v3 adds the archived flag; existing pacts default to not archived.
      await db.execute('ALTER TABLE pacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      // v4 adds provenance tracking for showup failures. DEFAULT 1 makes all
      // historical failed rows redeemable — correct for data-loss scenarios.
      await db.execute('ALTER TABLE showups ADD COLUMN redeemable INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 5) {
      // v5 adds the pact_breaks table (HAB-195).
      await db.execute('''
        CREATE TABLE pact_breaks (
          id                TEXT    NOT NULL PRIMARY KEY,
          pact_id           TEXT    NOT NULL,
          start_date        INTEGER NOT NULL,
          rationale         TEXT    NOT NULL,
          planned_end_date  INTEGER,
          created_at        INTEGER,
          stopped_at        INTEGER,
          dirty             INTEGER NOT NULL DEFAULT 1,
          synced_at         INTEGER,
          FOREIGN KEY (pact_id) REFERENCES pacts(id)
        )
      ''');
      await db.execute('CREATE INDEX idx_pact_breaks_pact_id ON pact_breaks (pact_id)');
    }
    if (oldVersion < 6) {
      // v6 adds pact chaining (HAB-202) — predecessor_pact_id links a pact to
      // the one it was adjusted from. No FK: see the runMigrations comment on
      // the same index for why.
      await db.execute('ALTER TABLE pacts ADD COLUMN predecessor_pact_id TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX idx_pacts_predecessor_pact_id ON pacts (predecessor_pact_id) '
        'WHERE predecessor_pact_id IS NOT NULL',
      );
    }
    if (oldVersion < 7) {
      // v7 adds the user_profile table (HAB-232) — a single-row store for the
      // user's optional display name, synced via the same Firestore machinery
      // as pacts/showups/pact_breaks. Additive only — no existing table touched.
      await db.execute('''
        CREATE TABLE user_profile (
          id            TEXT    NOT NULL PRIMARY KEY,
          display_name  TEXT,
          updated_at    INTEGER NOT NULL,
          dirty         INTEGER NOT NULL DEFAULT 0,
          synced_at     INTEGER
        )
      ''');
    }
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
        version: 7,
        onConfigure: (db) async {
          try {
            await db.rawQuery('PRAGMA journal_mode=WAL');
          } catch (_) {}
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: runMigrations,
        onUpgrade: runUpgradeMigrations,
      ),
    );
  }
}
