import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PactTransactionService', () {
    late Database db;
    late PactTransactionService service;

    final startDate = DateTime(2026, 1, 1);
    final endDate = DateTime(2026, 7, 1);
    final createdAt = DateTime(2026, 1, 1, 9, 0, 0);

    Pact makePact({String id = 'pact-1'}) => Pact(
          id: id,
          habitName: 'Meditate',
          startDate: startDate,
          endDate: endDate,
          showupDuration: const Duration(minutes: 30),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          createdAt: createdAt,
        );

    Showup makeShowup({required String id, required String pactId}) => Showup(
          id: id,
          pactId: pactId,
          scheduledAt: DateTime(2026, 1, 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.pending,
        );

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: HabitLoopDatabase.runMigrations,
          onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      service = SqlitePactTransactionService(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // savePactWithShowups
    // -------------------------------------------------------------------------

    group('savePactWithShowups', () {
      test('inserts pact with total_showups set to showups.length', () async {
        final pact = makePact();
        final showups = [
          makeShowup(id: 's1', pactId: 'pact-1'),
          makeShowup(id: 's2', pactId: 'pact-1'),
          makeShowup(id: 's3', pactId: 'pact-1'),
        ];

        await service.savePactWithShowups(pact, showups);

        final rows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(rows, hasLength(1));
        expect(rows.first['total_showups'], equals(3));
      });

      test('inserts all showup rows', () async {
        final pact = makePact();
        final showups = [
          makeShowup(id: 's1', pactId: 'pact-1'),
          makeShowup(id: 's2', pactId: 'pact-1'),
        ];

        await service.savePactWithShowups(pact, showups);

        final rows = await db.query('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
        expect(rows, hasLength(2));
        final ids = rows.map((r) => r['id'] as String).toSet();
        expect(ids, containsAll(['s1', 's2']));
      });

      test('works with an empty showup list — total_showups is 0', () async {
        final pact = makePact();

        await service.savePactWithShowups(pact, []);

        final rows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(rows, hasLength(1));
        expect(rows.first['total_showups'], equals(0));

        final showupRows = await db.query('showups');
        expect(showupRows, isEmpty);
      });

      test('rolls back pact insert when a showup insert fails', () async {
        final pact = makePact();
        // Use duplicate showup ids so the second insert triggers a conflict
        // (ConflictAlgorithm.fail) and the transaction rolls back.
        final showupsWithDuplicate = [
          makeShowup(id: 's1', pactId: 'pact-1'),
          makeShowup(id: 's1', pactId: 'pact-1'), // duplicate — will fail
        ];

        await expectLater(
          () => service.savePactWithShowups(pact, showupsWithDuplicate),
          throwsException,
        );

        // The pact row must be absent — the transaction rolled back.
        final pactRows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(pactRows, isEmpty, reason: 'pact must be rolled back when showup insert fails');

        // No orphaned showup rows either.
        final showupRows = await db.query('showups');
        expect(showupRows, isEmpty, reason: 'no showup rows may survive a partial transaction');
      });

      test('throws on duplicate pact id (ConflictAlgorithm.fail)', () async {
        final pact = makePact();
        await service.savePactWithShowups(pact, []);

        // A second insert with the same pact id must fail.
        await expectLater(
          () => service.savePactWithShowups(pact, []),
          throwsException,
        );
      });
    });

    // -------------------------------------------------------------------------
    // stopPactTransaction
    // -------------------------------------------------------------------------

    group('stopPactTransaction', () {
      test('updates pact row and deletes only showups scheduled after now', () async {
        final pact = makePact();
        // s1 is in the past relative to `now` below, s2 is in the future.
        final pastShowup = makeShowup(id: 's1', pactId: 'pact-1');
        final futureShowup = Showup(
          id: 's2',
          pactId: 'pact-1',
          scheduledAt: DateTime(2026, 3, 5, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.pending,
        );
        await service.savePactWithShowups(pact, [pastShowup, futureShowup]);

        final now = DateTime(2026, 3, 1);
        final stoppedPact = pact.copyWith(
          status: PactStatus.stopped,
          endDate: now,
          stopReason: 'Changed plans',
        );

        await service.stopPactTransaction(
          updatedPact: stoppedPact,
          pactId: 'pact-1',
          now: now,
        );

        // Pact status and actual_end_date updated.
        final pactRows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(pactRows, hasLength(1));
        expect(pactRows.first['status'], equals('stopped'));
        expect(pactRows.first['actual_end_date'], equals(now.millisecondsSinceEpoch));
        expect(pactRows.first['stop_reason'], equals('Changed plans'));

        // Only the future showup is deleted — the past one is real history
        // and must survive (HAB-208).
        final showupRows = await db.query('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
        expect(showupRows.map((r) => r['id']), equals(['s1']),
            reason: 'showups at or before now must be kept; only future ones are deleted');
      });

      test('keeps a future showup that was already manually marked done (HAB-208 audit)', () async {
        // A showup can be marked done/failed ahead of its scheduled time —
        // showup_detail_view_model.dart's markDone/markFailed only gate on
        // status == pending, with no time check. Deleting purely by schedule
        // date would silently drop that real history.
        final pact = makePact();
        final now = DateTime(2026, 3, 1);
        final futureDoneShowup = Showup(
          id: 's1',
          pactId: 'pact-1',
          scheduledAt: DateTime(2026, 3, 5, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
        );
        final futurePendingShowup = Showup(
          id: 's2',
          pactId: 'pact-1',
          scheduledAt: DateTime(2026, 3, 6, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.pending,
        );
        await service.savePactWithShowups(pact, [futureDoneShowup, futurePendingShowup]);

        final stoppedPact = pact.copyWith(status: PactStatus.stopped, endDate: now);
        await service.stopPactTransaction(updatedPact: stoppedPact, pactId: 'pact-1', now: now);

        final showupRows = await db.query('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
        expect(showupRows.map((r) => r['id']), equals(['s1']),
            reason: 'a future showup already marked done is real history and must survive; only the still-pending '
                'future showup should be deleted');
      });

      test('keeps a showup scheduled exactly at now', () async {
        final pact = makePact();
        final now = DateTime(2026, 3, 1, 8);
        final showupAtNow = Showup(
          id: 's1',
          pactId: 'pact-1',
          scheduledAt: now,
          duration: const Duration(minutes: 30),
          status: ShowupStatus.pending,
        );
        await service.savePactWithShowups(pact, [showupAtNow]);

        final stoppedPact = pact.copyWith(status: PactStatus.stopped, endDate: now);
        await service.stopPactTransaction(updatedPact: stoppedPact, pactId: 'pact-1', now: now);

        final showupRows = await db.query('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
        expect(showupRows, hasLength(1), reason: 'a showup scheduled exactly at now must not be deleted');
      });

      test('preserves scheduled_end_date after stop', () async {
        final pact = makePact();
        await service.savePactWithShowups(pact, []);

        final stopDate = DateTime(2026, 3, 1);
        final stoppedPact = pact.copyWith(status: PactStatus.stopped, endDate: stopDate);
        await service.stopPactTransaction(updatedPact: stoppedPact, pactId: 'pact-1', now: stopDate);

        final pactRows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(
          pactRows.first['scheduled_end_date'],
          equals(endDate.millisecondsSinceEpoch),
          reason: 'scheduled_end_date must remain the original planned end date',
        );
        expect(
          pactRows.first['actual_end_date'],
          equals(stopDate.millisecondsSinceEpoch),
          reason: 'actual_end_date must be updated to the stop date',
        );
      });

      test('preserves total_showups after stop', () async {
        final pact = makePact();
        final showups = [
          makeShowup(id: 's1', pactId: 'pact-1'),
          makeShowup(id: 's2', pactId: 'pact-1'),
        ];
        await service.savePactWithShowups(pact, showups);

        final stopDate = DateTime(2026, 3, 1);
        final stoppedPact = pact.copyWith(status: PactStatus.stopped, endDate: stopDate);
        await service.stopPactTransaction(updatedPact: stoppedPact, pactId: 'pact-1', now: stopDate);

        final pactRows = await db.query('pacts', where: 'id = ?', whereArgs: ['pact-1']);
        expect(
          pactRows.first['total_showups'],
          equals(2),
          reason: 'total_showups must not be zeroed out by stopPactTransaction',
        );
      });

      test('throws StateError when pact id does not exist', () async {
        final nonExistentPact = makePact(id: 'does-not-exist');
        final now = DateTime(2026, 3, 1);
        final stoppedPact = nonExistentPact.copyWith(
          status: PactStatus.stopped,
          endDate: now,
        );

        await expectLater(
          () => service.stopPactTransaction(updatedPact: stoppedPact, pactId: 'does-not-exist', now: now),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
