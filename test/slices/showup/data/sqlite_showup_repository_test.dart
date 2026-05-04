import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteShowupRepository', () {
    late Database db;
    late SqliteShowupRepository repository;

    // A parent pact required for FK constraints.
    final pact = Pact(
      id: 'pact-1',
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      showupDuration: const Duration(minutes: 30),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
      createdAt: DateTime(2026, 1, 1, 9, 0, 0),
    );

    Showup makeShowup({
      String id = 'showup-1',
      String pactId = 'pact-1',
      DateTime? scheduledAt,
      ShowupStatus status = ShowupStatus.pending,
      String? note,
    }) =>
        Showup(
          id: id,
          pactId: pactId,
          scheduledAt: scheduledAt ?? DateTime(2026, 1, 1, 8, 0),
          duration: const Duration(minutes: 30),
          status: status,
          note: note,
        );

    /// Insert the parent pact directly so FK constraints are satisfied.
    Future<void> insertPact([Pact? p]) async {
      final row = PactMapper.toRow(p ?? pact);
      await db.insert('pacts', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: HabitLoopDatabase.runMigrations),
      );
      repository = SqliteShowupRepository(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // saveShowup
    // -------------------------------------------------------------------------

    group('saveShowup', () {
      test('persists a showup that can be retrieved', () async {
        await insertPact();
        final showup = makeShowup();
        await repository.saveShowup(showup);

        final retrieved = await repository.getShowupById('showup-1');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('showup-1'));
        expect(retrieved.pactId, equals('pact-1'));
        expect(retrieved.status, equals(ShowupStatus.pending));
      });

      test('throws ArgumentError when showup with same id already exists', () async {
        await insertPact();
        await repository.saveShowup(makeShowup());
        await expectLater(() => repository.saveShowup(makeShowup()), throwsArgumentError);
      });

      test('preserves local-time scheduledAt', () async {
        await insertPact();
        final scheduledAt = DateTime(2026, 3, 15, 8, 30);
        await repository.saveShowup(makeShowup(scheduledAt: scheduledAt));

        final retrieved = await repository.getShowupById('showup-1');
        expect(retrieved!.scheduledAt.isUtc, isFalse);
        expect(retrieved.scheduledAt, equals(scheduledAt));
      });

      test('preserves note', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(note: 'Felt great'));
        final retrieved = await repository.getShowupById('showup-1');
        expect(retrieved!.note, equals('Felt great'));
      });

      test('preserves null note', () async {
        await insertPact();
        await repository.saveShowup(makeShowup());
        final retrieved = await repository.getShowupById('showup-1');
        expect(retrieved!.note, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // saveShowups (batch)
    // -------------------------------------------------------------------------

    group('saveShowups', () {
      test('saves multiple showups atomically', () async {
        await insertPact();
        final showups = [
          makeShowup(id: 's1', scheduledAt: DateTime(2026, 1, 1, 8, 0)),
          makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 2, 8, 0)),
          makeShowup(id: 's3', scheduledAt: DateTime(2026, 1, 3, 8, 0)),
        ];
        final result = await repository.saveShowups(showups);
        expect(result.savedCount, equals(3));
        expect(result.skippedIds, isEmpty);
      });

      test('skips showups whose ids already exist', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1'));
        final showups = [
          makeShowup(id: 's1'),
          makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 2, 8, 0)),
        ];
        final result = await repository.saveShowups(showups);
        expect(result.savedCount, equals(1));
        expect(result.skippedIds, contains('s1'));
      });

      test('returns savedCount=0 and all ids skipped when all already exist', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1'));
        final result = await repository.saveShowups([makeShowup(id: 's1')]);
        expect(result.savedCount, equals(0));
        expect(result.skippedIds, equals(['s1']));
      });

      test('empty list returns savedCount=0', () async {
        final result = await repository.saveShowups([]);
        expect(result.savedCount, equals(0));
        expect(result.skippedIds, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getShowupById
    // -------------------------------------------------------------------------

    group('getShowupById', () {
      test('returns null for non-existent id', () async {
        final result = await repository.getShowupById('non-existent');
        expect(result, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // getShowupsForPact
    // -------------------------------------------------------------------------

    group('getShowupsForPact', () {
      test('returns showups for the given pactId', () async {
        await insertPact();
        await insertPact(
          Pact(
            id: 'pact-2',
            habitName: 'Jog',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 7, 1),
            showupDuration: const Duration(minutes: 20),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
            createdAt: DateTime(2026, 1, 1, 7, 0, 0),
          ),
        );
        await repository.saveShowup(makeShowup(id: 's1', pactId: 'pact-1'));
        await repository.saveShowup(makeShowup(id: 's2', pactId: 'pact-2'));
        await repository.saveShowup(makeShowup(id: 's3', pactId: 'pact-1', scheduledAt: DateTime(2026, 1, 2, 8, 0)));

        final result = await repository.getShowupsForPact('pact-1');
        expect(result, hasLength(2));
        expect(result.every((s) => s.pactId == 'pact-1'), isTrue);
      });

      test('returns empty list when no showups for pact', () async {
        final result = await repository.getShowupsForPact('non-existent');
        expect(result, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getShowupsForDate
    // -------------------------------------------------------------------------

    group('getShowupsForDate', () {
      test('returns showups scheduled on the given day', () async {
        await insertPact();
        final targetDate = DateTime(2026, 3, 15);
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: DateTime(2026, 3, 15, 7, 0)));
        await repository.saveShowup(makeShowup(id: 's2', scheduledAt: DateTime(2026, 3, 15, 20, 0)));
        await repository.saveShowup(makeShowup(id: 's3', scheduledAt: DateTime(2026, 3, 16, 7, 0)));

        final result = await repository.getShowupsForDate(targetDate);
        expect(result, hasLength(2));
        expect(result.every((s) => s.scheduledAt.day == 15), isTrue);
      });

      test('midnight is included in the target day (not the previous day)', () async {
        await insertPact();
        final midnight = DateTime(2026, 3, 15, 0, 0, 0);
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: midnight));

        final result = await repository.getShowupsForDate(DateTime(2026, 3, 15));
        expect(result, hasLength(1));
      });

      test('23:59:59.999 is included in the target day', () async {
        await insertPact();
        final almostMidnight = DateTime(2026, 3, 15, 23, 59, 59, 999);
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: almostMidnight));

        final result = await repository.getShowupsForDate(DateTime(2026, 3, 15));
        expect(result, hasLength(1));
      });

      test('next-day midnight is NOT included in the current day', () async {
        await insertPact();
        final nextDayMidnight = DateTime(2026, 3, 16, 0, 0, 0);
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: nextDayMidnight));

        final result = await repository.getShowupsForDate(DateTime(2026, 3, 15));
        expect(result, isEmpty);
      });

      test('returns empty list when no showups on that day', () async {
        final result = await repository.getShowupsForDate(DateTime(2026, 3, 15));
        expect(result, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getShowupsForDateRange
    // -------------------------------------------------------------------------

    group('getShowupsForDateRange', () {
      test('returns showups within the date range inclusive', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: DateTime(2026, 1, 1, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 3, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's3', scheduledAt: DateTime(2026, 1, 5, 8, 0)));

        final result = await repository.getShowupsForDateRange(
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 3),
        );
        expect(result, hasLength(2));
      });

      test('excludes showups outside the date range', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: DateTime(2025, 12, 31, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 2, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's3', scheduledAt: DateTime(2026, 1, 10, 8, 0)));

        final result = await repository.getShowupsForDateRange(
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 5),
        );
        expect(result, hasLength(1));
        expect(result.first.id, equals('s2'));
      });
    });

    // -------------------------------------------------------------------------
    // updateShowup
    // -------------------------------------------------------------------------

    group('updateShowup', () {
      test('updates status of an existing showup', () async {
        await insertPact();
        await repository.saveShowup(makeShowup());
        final updated = makeShowup(status: ShowupStatus.done, note: 'Completed!');
        await repository.updateShowup(updated);

        final retrieved = await repository.getShowupById('showup-1');
        expect(retrieved!.status, equals(ShowupStatus.done));
        expect(retrieved.note, equals('Completed!'));
      });

      test('throws ArgumentError when showup does not exist', () async {
        await expectLater(() => repository.updateShowup(makeShowup()), throwsArgumentError);
      });
    });

    // -------------------------------------------------------------------------
    // countShowupsForPact
    // -------------------------------------------------------------------------

    group('countShowupsForPact', () {
      test('returns 0 when no showups for pact', () async {
        final count = await repository.countShowupsForPact('pact-1');
        expect(count, equals(0));
      });

      test('returns correct count', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: DateTime(2026, 1, 1, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 2, 8, 0)));

        final count = await repository.countShowupsForPact('pact-1');
        expect(count, equals(2));
      });
    });

    // -------------------------------------------------------------------------
    // deleteShowupsForPact
    // -------------------------------------------------------------------------

    group('deleteShowupsForPact', () {
      test('removes all showups for the given pact', () async {
        await insertPact();
        await repository.saveShowup(makeShowup(id: 's1', scheduledAt: DateTime(2026, 1, 1, 8, 0)));
        await repository.saveShowup(makeShowup(id: 's2', scheduledAt: DateTime(2026, 1, 2, 8, 0)));
        await repository.deleteShowupsForPact('pact-1');

        final result = await repository.getShowupsForPact('pact-1');
        expect(result, isEmpty);
      });

      test('no-op when no showups for pact', () async {
        await expectLater(() => repository.deleteShowupsForPact('non-existent'), returnsNormally);
      });

      test('only deletes showups for the targeted pact', () async {
        await insertPact();
        await insertPact(
          Pact(
            id: 'pact-2',
            habitName: 'Jog',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 7, 1),
            showupDuration: const Duration(minutes: 20),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
            createdAt: DateTime(2026, 1, 1, 7, 0, 0),
          ),
        );
        await repository.saveShowup(makeShowup(id: 's1', pactId: 'pact-1'));
        await repository.saveShowup(makeShowup(id: 's2', pactId: 'pact-2'));
        await repository.deleteShowupsForPact('pact-1');

        final remaining = await repository.getShowupsForPact('pact-2');
        expect(remaining, hasLength(1));
      });
    });
  });
}
