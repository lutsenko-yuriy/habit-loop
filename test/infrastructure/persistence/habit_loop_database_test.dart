import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HabitLoopDatabase — WAL journal mode', () {
    test('WAL mode is active on a file-backed database opened via onConfigure', () async {
      // SQLite in-memory databases always report journal_mode=memory regardless of
      // PRAGMA journal_mode=WAL. To verify the onConfigure WAL setup works we must
      // use a real (file-backed) database. A temp file is created and deleted after.
      final tmpPath = '${Directory.systemTemp.path}/habit_loop_wal_test.db';
      final db = await databaseFactoryFfi.openDatabase(
        tmpPath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA journal_mode=WAL');
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: HabitLoopDatabase.runMigrations,
        ),
      );
      try {
        final result = await db.rawQuery('PRAGMA journal_mode');
        expect(result.first.values.first, 'wal');
      } finally {
        await db.close();
        try {
          File(tmpPath).deleteSync();
          File('$tmpPath-wal').deleteSync();
          File('$tmpPath-shm').deleteSync();
        } catch (_) {}
      }
    });

    test('openForTesting returns memory journal mode (WAL not applicable to in-memory databases)', () async {
      // This documents the known behaviour: WAL PRAGMA is sent during onConfigure
      // but SQLite ignores it for :memory: databases and keeps journal_mode=memory.
      final db = await HabitLoopDatabase.openForTesting();
      try {
        final result = await db.rawQuery('PRAGMA journal_mode');
        expect(result.first.values.first, 'memory');
      } finally {
        await db.close();
      }
    });
  });

  group('HabitLoopDatabase.runMigrations', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: HabitLoopDatabase.runMigrations),
      );
    });

    tearDown(() async => db.close());

    test('creates the pacts table', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pacts'",
      );
      expect(result, hasLength(1));
    });

    test('creates the showups table', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='showups'",
      );
      expect(result, hasLength(1));
    });

    test('creates idx_showups_pact_id index', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_showups_pact_id'",
      );
      expect(result, hasLength(1));
    });

    test('creates idx_showups_scheduled_at index', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_showups_scheduled_at'",
      );
      expect(result, hasLength(1));
    });

    test('pacts table has expected columns', () async {
      final result = await db.rawQuery('PRAGMA table_info(pacts)');
      final columnNames = result.map((row) => row['name'] as String).toSet();
      expect(
        columnNames,
        containsAll([
          'id',
          'habit_name',
          'start_date',
          'scheduled_end_date',
          'actual_end_date',
          'showup_duration',
          'schedule',
          'reminder_offset',
          'status',
          'stop_reason',
          'total_showups',
          'created_at',
          'dirty',
          'synced_at',
          'archived',
        ]),
      );
    });

    test('showups table has expected columns', () async {
      final result = await db.rawQuery('PRAGMA table_info(showups)');
      final columnNames = result.map((row) => row['name'] as String).toSet();
      expect(
        columnNames,
        containsAll(
            ['id', 'pact_id', 'scheduled_at', 'duration', 'status', 'note', 'redeemable', 'dirty', 'synced_at']),
      );
    });

    test('can insert a pact row', () async {
      final rowsAffected = await db.rawInsert(
        'INSERT INTO pacts (id, habit_name, start_date, scheduled_end_date, actual_end_date, '
        'showup_duration, schedule, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        ['pact-1', 'Meditate', 0, 1000, 1000, 600000000, '{"type":"daily","timeOfDay":28800000000}', 'active', 0],
      );
      expect(rowsAffected, equals(1));
    });

    test('can insert a showup row after inserting its pact', () async {
      await db.rawInsert(
        'INSERT INTO pacts (id, habit_name, start_date, scheduled_end_date, actual_end_date, '
        'showup_duration, schedule, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        ['pact-1', 'Meditate', 0, 1000, 1000, 600000000, '{"type":"daily","timeOfDay":28800000000}', 'active', 0],
      );
      final rowsAffected = await db.rawInsert(
        'INSERT INTO showups (id, pact_id, scheduled_at, duration, status) VALUES (?, ?, ?, ?, ?)',
        ['showup-1', 'pact-1', 0, 600000000, 'pending'],
      );
      expect(rowsAffected, equals(1));
    });
  });

  group('HabitLoopDatabase — migration v1 → v2', () {
    late Database db;

    // Raw v1 DDL without dirty/synced_at — used to simulate an existing
    // v1 installation before the upgrade migration is applied.
    Future<void> createV1Schema(Database db) async {
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

    setUp(() async {
      // Open a raw in-memory database with the v1 schema (no dirty/synced_at).
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await createV1Schema(db);
      // Insert a pact and a showup so we can verify existing rows get dirty=1.
      await db.rawInsert(
        'INSERT INTO pacts (id, habit_name, start_date, scheduled_end_date, actual_end_date, '
        'showup_duration, schedule, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['pact-1', 'Meditate', 0, 1000, 1000, 600000000, '{"type":"daily","timeOfDay":28800000000}', 'active'],
      );
      await db.rawInsert(
        'INSERT INTO showups (id, pact_id, scheduled_at, duration, status) VALUES (?, ?, ?, ?, ?)',
        ['showup-1', 'pact-1', 0, 600000000, 'pending'],
      );
    });

    tearDown(() async => db.close());

    test('upgrade adds dirty column to pacts with default 1', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 1, 2);
      final rows = await db.rawQuery('SELECT dirty FROM pacts WHERE id = ?', ['pact-1']);
      expect(rows.first['dirty'], equals(1));
    });

    test('upgrade adds synced_at column to pacts as null', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 1, 2);
      final rows = await db.rawQuery('SELECT synced_at FROM pacts WHERE id = ?', ['pact-1']);
      expect(rows.first['synced_at'], isNull);
    });

    test('upgrade adds dirty column to showups with default 1', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 1, 2);
      final rows = await db.rawQuery('SELECT dirty FROM showups WHERE id = ?', ['showup-1']);
      expect(rows.first['dirty'], equals(1));
    });

    test('upgrade adds synced_at column to showups as null', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 1, 2);
      final rows = await db.rawQuery('SELECT synced_at FROM showups WHERE id = ?', ['showup-1']);
      expect(rows.first['synced_at'], isNull);
    });
  });

  group('HabitLoopDatabase — migration v2 → v3', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      // Build a v2 schema manually (pacts without archived column).
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
          synced_at            INTEGER
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
          dirty        INTEGER NOT NULL DEFAULT 1,
          synced_at    INTEGER,
          FOREIGN KEY (pact_id) REFERENCES pacts(id)
        )
      ''');
      await db.rawInsert(
        'INSERT INTO pacts (id, habit_name, start_date, scheduled_end_date, actual_end_date, '
        'showup_duration, schedule, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['pact-1', 'Meditate', 0, 1000, 1000, 600000000, '{"type":"daily","timeOfDay":28800000000}', 'active'],
      );
    });

    tearDown(() async => db.close());

    test('upgrade adds archived column to pacts with default 0', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 2, 3);
      final rows = await db.rawQuery('SELECT archived FROM pacts WHERE id = ?', ['pact-1']);
      expect(rows.first['archived'], equals(0));
    });

    test('pacts table has archived column after v2→v3', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 2, 3);
      final result = await db.rawQuery('PRAGMA table_info(pacts)');
      final columnNames = result.map((row) => row['name'] as String).toSet();
      expect(columnNames, contains('archived'));
    });
  });

  group('HabitLoopDatabase — migration v3 → v4', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      // Build a v3 schema manually (showups without redeemable column).
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
          archived             INTEGER NOT NULL DEFAULT 0
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
          dirty        INTEGER NOT NULL DEFAULT 1,
          synced_at    INTEGER,
          FOREIGN KEY (pact_id) REFERENCES pacts(id)
        )
      ''');
      await db.rawInsert(
        'INSERT INTO pacts (id, habit_name, start_date, scheduled_end_date, actual_end_date, '
        'showup_duration, schedule, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['pact-1', 'Meditate', 0, 1000, 1000, 600000000, '{"type":"daily","timeOfDay":28800000000}', 'active'],
      );
      await db.rawInsert(
        'INSERT INTO showups (id, pact_id, scheduled_at, duration, status) VALUES (?, ?, ?, ?, ?)',
        ['showup-1', 'pact-1', 0, 600000000, 'failed'],
      );
    });

    tearDown(() async => db.close());

    test('upgrade adds redeemable column to showups with default 1', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 3, 4);
      final rows = await db.rawQuery('SELECT redeemable FROM showups WHERE id = ?', ['showup-1']);
      expect(rows.first['redeemable'], equals(1));
    });

    test('showups table has redeemable column after v3→v4', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 3, 4);
      final result = await db.rawQuery('PRAGMA table_info(showups)');
      final columnNames = result.map((row) => row['name'] as String).toSet();
      expect(columnNames, contains('redeemable'));
    });

    test('existing failed rows become redeemable=1 (eligible) after migration', () async {
      await HabitLoopDatabase.runUpgradeMigrations(db, 3, 4);
      final rows = await db.rawQuery(
        'SELECT redeemable FROM showups WHERE id = ? AND status = ?',
        ['showup-1', 'failed'],
      );
      expect(rows.first['redeemable'], equals(1));
    });
  });
}
