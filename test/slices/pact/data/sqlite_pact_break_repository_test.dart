import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_break_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqlitePactBreakRepository', () {
    late Database db;
    late SqlitePactBreakRepository repository;

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

    PactBreak makeBreak({
      String id = 'break-1',
      String pactId = 'pact-1',
      DateTime? startDate,
      DateTime? plannedEndDate,
      DateTime? stoppedAt,
      String rationale = 'Recovering from a cold',
    }) =>
        PactBreak(
          id: id,
          pactId: pactId,
          startDate: startDate ?? DateTime(2026, 3, 1),
          rationale: rationale,
          plannedEndDate: plannedEndDate,
          stoppedAt: stoppedAt,
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
      repository = SqlitePactBreakRepository(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // saveBreak
    // -------------------------------------------------------------------------

    group('saveBreak', () {
      test('persists a break that can be retrieved via getBreaksForPact', () async {
        await insertPact();
        await repository.saveBreak(makeBreak());

        final breaks = await repository.getBreaksForPact('pact-1');
        expect(breaks, hasLength(1));
        expect(breaks.first.id, equals('break-1'));
        expect(breaks.first.pactId, equals('pact-1'));
        expect(breaks.first.rationale, equals('Recovering from a cold'));
      });

      test('throws ArgumentError if a break with the same id already exists', () async {
        await insertPact();
        await repository.saveBreak(makeBreak());

        expect(() => repository.saveBreak(makeBreak()), throwsArgumentError);
      });
    });

    // -------------------------------------------------------------------------
    // updateBreak
    // -------------------------------------------------------------------------

    group('updateBreak', () {
      test('persists changes to an existing break', () async {
        await insertPact();
        await repository.saveBreak(makeBreak());

        final stoppedAt = DateTime(2026, 3, 5);
        await repository.updateBreak(makeBreak(stoppedAt: stoppedAt));

        final breaks = await repository.getBreaksForPact('pact-1');
        expect(breaks.first.stoppedAt, equals(stoppedAt));
      });

      test('throws ArgumentError if no break with the given id exists', () async {
        await insertPact();
        expect(() => repository.updateBreak(makeBreak()), throwsArgumentError);
      });
    });

    // -------------------------------------------------------------------------
    // getBreaksForPact
    // -------------------------------------------------------------------------

    group('getBreaksForPact', () {
      test('returns an empty list when no breaks exist for the pact', () async {
        await insertPact();
        expect(await repository.getBreaksForPact('pact-1'), isEmpty);
      });

      test('only returns breaks belonging to the given pact', () async {
        await insertPact();
        await insertPact(
          Pact(
            id: 'pact-2',
            habitName: 'Jog',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 7, 1),
            showupDuration: const Duration(minutes: 30),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
            status: PactStatus.active,
            createdAt: DateTime(2026, 1, 1, 9, 0, 0),
          ),
        );
        await repository.saveBreak(makeBreak(id: 'break-1', pactId: 'pact-1'));
        await repository.saveBreak(makeBreak(id: 'break-2', pactId: 'pact-2'));

        final breaks = await repository.getBreaksForPact('pact-1');
        expect(breaks, hasLength(1));
        expect(breaks.first.id, equals('break-1'));
      });

      test('returns breaks oldest-start-date first', () async {
        await insertPact();
        await repository.saveBreak(makeBreak(id: 'break-later', startDate: DateTime(2026, 3, 10)));
        await repository.saveBreak(makeBreak(id: 'break-earlier', startDate: DateTime(2026, 3, 1)));

        final breaks = await repository.getBreaksForPact('pact-1');
        expect(breaks.map((b) => b.id).toList(), equals(['break-earlier', 'break-later']));
      });
    });
  });
}
