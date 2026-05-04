import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqlitePactRepository', () {
    late Database db;
    late SqlitePactRepository repository;

    final startDate = DateTime(2026, 1, 1);
    final endDate = DateTime(2026, 7, 1);
    final createdAt = DateTime(2026, 1, 1, 9, 0, 0);

    Pact makePact({
      String id = 'pact-1',
      String habitName = 'Meditate',
      PactStatus status = PactStatus.active,
      String? stopReason,
    }) =>
        Pact(
          id: id,
          habitName: habitName,
          startDate: startDate,
          endDate: endDate,
          showupDuration: const Duration(minutes: 30),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: status,
          createdAt: createdAt,
          stopReason: stopReason,
        );

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: HabitLoopDatabase.runMigrations),
      );
      repository = SqlitePactRepository(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // savePact
    // -------------------------------------------------------------------------

    group('savePact', () {
      test('persists a pact that can be retrieved', () async {
        final pact = makePact();
        await repository.savePact(pact);

        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('pact-1'));
        expect(retrieved.habitName, equals('Meditate'));
        expect(retrieved.startDate, equals(startDate));
        expect(retrieved.endDate, equals(endDate));
        expect(retrieved.status, equals(PactStatus.active));
      });

      test('throws ArgumentError when pact with same id already exists', () async {
        final pact = makePact();
        await repository.savePact(pact);
        await expectLater(() => repository.savePact(pact), throwsArgumentError);
      });

      test('preserves local-time DateTime fields', () async {
        final pact = makePact();
        await repository.savePact(pact);

        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.startDate.isUtc, isFalse);
        expect(retrieved.startDate, equals(startDate));
        expect(retrieved.endDate.isUtc, isFalse);
        expect(retrieved.endDate, equals(endDate));
      });

      test('preserves optional reminderOffset', () async {
        final pact = makePact().copyWith(reminderOffset: const Duration(minutes: 15));
        await repository.savePact(pact);

        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.reminderOffset, equals(const Duration(minutes: 15)));
      });

      test('preserves null reminderOffset', () async {
        await repository.savePact(makePact());
        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.reminderOffset, isNull);
      });

      test('preserves stopReason', () async {
        final pact = makePact(status: PactStatus.stopped, stopReason: 'Too busy');
        await repository.savePact(pact);

        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.stopReason, equals('Too busy'));
      });

      test('stats is always null after retrieval', () async {
        await repository.savePact(makePact());
        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.stats, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // getPactById
    // -------------------------------------------------------------------------

    group('getPactById', () {
      test('returns null for non-existent id', () async {
        final result = await repository.getPactById('non-existent');
        expect(result, isNull);
      });

      test('returns correct pact when multiple pacts exist', () async {
        await repository.savePact(makePact(id: 'pact-1'));
        await repository.savePact(makePact(id: 'pact-2', habitName: 'Jog'));

        final result = await repository.getPactById('pact-2');
        expect(result!.habitName, equals('Jog'));
      });
    });

    // -------------------------------------------------------------------------
    // getAllPacts
    // -------------------------------------------------------------------------

    group('getAllPacts', () {
      test('returns empty list when no pacts exist', () async {
        final result = await repository.getAllPacts();
        expect(result, isEmpty);
      });

      test('returns all pacts regardless of status', () async {
        await repository.savePact(makePact(id: 'p1', status: PactStatus.active));
        await repository.savePact(makePact(id: 'p2', status: PactStatus.stopped));
        await repository.savePact(makePact(id: 'p3', status: PactStatus.completed));

        final result = await repository.getAllPacts();
        expect(result, hasLength(3));
      });
    });

    // -------------------------------------------------------------------------
    // getActivePacts
    // -------------------------------------------------------------------------

    group('getActivePacts', () {
      test('returns empty list when no active pacts exist', () async {
        await repository.savePact(makePact(id: 'p1', status: PactStatus.stopped));
        final result = await repository.getActivePacts();
        expect(result, isEmpty);
      });

      test('returns only active pacts', () async {
        await repository.savePact(makePact(id: 'p1', status: PactStatus.active));
        await repository.savePact(makePact(id: 'p2', status: PactStatus.stopped));
        await repository.savePact(makePact(id: 'p3', status: PactStatus.active));

        final result = await repository.getActivePacts();
        expect(result, hasLength(2));
        expect(result.every((p) => p.status == PactStatus.active), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // updatePact
    // -------------------------------------------------------------------------

    group('updatePact', () {
      test('updates an existing pact', () async {
        await repository.savePact(makePact());
        final updated = makePact(status: PactStatus.stopped, stopReason: 'Quit');
        await repository.updatePact(updated);

        final retrieved = await repository.getPactById('pact-1');
        expect(retrieved!.status, equals(PactStatus.stopped));
        expect(retrieved.stopReason, equals('Quit'));
      });

      test('throws ArgumentError when pact does not exist', () async {
        await expectLater(() => repository.updatePact(makePact()), throwsArgumentError);
      });

      test('updated pact appears in getAllPacts with new values', () async {
        await repository.savePact(makePact(status: PactStatus.active));
        await repository.updatePact(makePact(status: PactStatus.completed));

        final all = await repository.getAllPacts();
        expect(all.first.status, equals(PactStatus.completed));
      });

      test('updatePact does NOT overwrite scheduled_end_date', () async {
        await repository.savePact(makePact());
        // The pact object still has the same endDate — this simulates a stop-pact
        // path that sets actualEndDate to today but should not clobber the planned end.
        final updated = makePact(status: PactStatus.stopped, stopReason: 'Quitting');
        await repository.updatePact(updated);

        // Read the raw row to verify the immutable column is intact.
        final rows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(rows, hasLength(1));
        expect(
          rows.first['scheduled_end_date'],
          equals(endDate.millisecondsSinceEpoch),
          reason: 'scheduled_end_date must survive an updatePact call',
        );
      });

      test('updatePact does NOT zero out a pre-existing total_showups value', () async {
        await repository.savePact(makePact());
        // Simulate WU3 writing total_showups after initial insert.
        await db.rawUpdate('UPDATE pacts SET total_showups = 182 WHERE id = ?', ['pact-1']);

        final updated = makePact(status: PactStatus.stopped, stopReason: 'Tired');
        await repository.updatePact(updated);

        final rows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(rows.first['total_showups'], equals(182), reason: 'total_showups must not be nulled by updatePact');
      });
    });

    // -------------------------------------------------------------------------
    // deletePact
    // -------------------------------------------------------------------------

    group('deletePact', () {
      test('removes the pact from storage', () async {
        await repository.savePact(makePact());
        await repository.deletePact('pact-1');
        final result = await repository.getPactById('pact-1');
        expect(result, isNull);
      });

      test('no-op when pact does not exist', () async {
        await expectLater(() => repository.deletePact('non-existent'), returnsNormally);
      });

      test('only deletes the targeted pact', () async {
        await repository.savePact(makePact(id: 'p1'));
        await repository.savePact(makePact(id: 'p2'));
        await repository.deletePact('p1');

        final all = await repository.getAllPacts();
        expect(all, hasLength(1));
        expect(all.first.id, equals('p2'));
      });
    });
  });
}
