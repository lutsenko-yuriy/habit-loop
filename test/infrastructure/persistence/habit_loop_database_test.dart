import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
        ]),
      );
    });

    test('showups table has expected columns', () async {
      final result = await db.rawQuery('PRAGMA table_info(showups)');
      final columnNames = result.map((row) => row['name'] as String).toSet();
      expect(columnNames, containsAll(['id', 'pact_id', 'scheduled_at', 'duration', 'status', 'note']));
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
}
