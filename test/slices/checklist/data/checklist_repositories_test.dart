import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_repository.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/checklist/data/sqlite_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/sqlite_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _pact = Pact(
  id: 'pact-1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 7, 1),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: DateTime(2026, 1, 1, 9),
);
final _showup = Showup(
  id: 'showup-1',
  pactId: 'pact-1',
  scheduledAt: DateTime(2026, 3, 1, 8),
  duration: const Duration(minutes: 30),
  status: ShowupStatus.pending,
);

PactChecklistLink _link({String pactId = 'pact-1', String checklistId = 'c1', String name = 'Morning'}) =>
    PactChecklistLink(pactId: pactId, checklistId: checklistId, checklistName: name, linkedAt: DateTime(2026, 2, 1, 9));

void _linkContract(String name, Future<PactChecklistLinkRepository> Function() make) {
  group('$name (link contract)', () {
    late PactChecklistLinkRepository repo;
    setUp(() async => repo = await make());

    test('getForPact returns null when absent', () async => expect(await repo.getForPact('pact-1'), isNull));

    test('upsert then get round-trips', () async {
      await repo.upsert(_link());
      expect(await repo.getForPact('pact-1'), _link());
    });

    test('upsert replaces the existing link', () async {
      await repo.upsert(_link());
      await repo.upsert(_link(checklistId: 'c2', name: 'Evening'));
      expect((await repo.getForPact('pact-1'))!.checklistId, 'c2');
    });

    test('getForPacts returns only existing links, keyed by pact id', () async {
      await repo.upsert(_link());
      final result = await repo.getForPacts(['pact-1', 'missing']);
      expect(result.keys, ['pact-1']);
      expect(await repo.getForPacts([]), isEmpty);
    });

    test('upsert for an unknown pact id is accepted', () async {
      await repo.upsert(_link(pactId: 'ghost'));
      expect(await repo.getForPact('ghost'), isNotNull);
    });

    test('delete removes the link; deleting an absent link is a no-op', () async {
      await repo.upsert(_link());
      await repo.delete('pact-1');
      await repo.delete('pact-1');
      expect(await repo.getForPact('pact-1'), isNull);
    });
  });
}

void _runContract(String name, Future<ChecklistRunRepository> Function() make) {
  group('$name (run contract)', () {
    late ChecklistRunRepository repo;
    setUp(() async => repo = await make());
    final t0 = DateTime(2026, 3, 1, 8);

    Future<ChecklistRun> start(DateTime at, {String checklistId = 'c1'}) =>
        repo.upsertStarted(showupId: 'showup-1', pactId: 'pact-1', checklistId: checklistId, startedAt: at);

    test('getForShowup returns null when absent', () async => expect(await repo.getForShowup('showup-1'), isNull));

    test('upsertStarted creates an unfinished run', () async {
      final run = await start(t0);
      expect(run.isFinished, isFalse);
      expect(await repo.getForShowup('showup-1'), run);
    });

    test('upsertStarted on an unfinished run overwrites startedAt', () async {
      await start(t0);
      final again = await start(t0.add(const Duration(minutes: 3)));
      expect(again.startedAt, t0.add(const Duration(minutes: 3)));
      expect((await repo.getForShowup('showup-1'))!.startedAt, again.startedAt);
    });

    test('markFinished finishes an unfinished run', () async {
      await start(t0);
      final done = await repo.markFinished(
        showupId: 'showup-1',
        finishedAt: t0.add(const Duration(minutes: 5)),
        outcome: ChecklistRunOutcome.success,
      );
      expect(done!.outcome, ChecklistRunOutcome.success);
      expect(await repo.getForShowup('showup-1'), done);
    });

    test('markFinished with no run returns null and creates nothing', () async {
      final result =
          await repo.markFinished(showupId: 'showup-1', finishedAt: t0, outcome: ChecklistRunOutcome.success);
      expect(result, isNull);
      expect(await repo.getForShowup('showup-1'), isNull);
    });

    test('a finished run is final: restart and re-finish change nothing', () async {
      await start(t0);
      final done = await repo.markFinished(
        showupId: 'showup-1',
        finishedAt: t0.add(const Duration(minutes: 5)),
        outcome: ChecklistRunOutcome.failure,
      );
      final restarted = await start(t0.add(const Duration(minutes: 9)), checklistId: 'other');
      expect(restarted, done);
      final second = await repo.markFinished(
        showupId: 'showup-1',
        finishedAt: t0.add(const Duration(minutes: 10)),
        outcome: ChecklistRunOutcome.success,
      );
      expect(second, isNull);
      expect(await repo.getForShowup('showup-1'), done);
    });

    test('upsertStarted for an unknown showup/pact id is accepted', () async {
      final run = await repo.upsertStarted(showupId: 'ghost', pactId: 'ghost-pact', checklistId: 'c1', startedAt: t0);
      expect(await repo.getForShowup('ghost'), run);
    });

    test('getForShowups returns only existing runs, keyed by showup id', () async {
      await start(t0);
      final result = await repo.getForShowups(['showup-1', 'missing']);
      expect(result.keys, ['showup-1']);
      expect(await repo.getForShowups([]), isEmpty);
    });
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Database? db;
  Future<Database> openDb() async {
    final d = await HabitLoopDatabase.openForTesting();
    await d.insert('pacts', PactMapper.toRow(_pact));
    await d.insert('showups', ShowupMapper.toRow(_showup));
    db = d;
    return d;
  }

  tearDown(() async {
    await db?.close();
    db = null;
  });

  _linkContract('InMemoryPactChecklistLinkRepository', () async => InMemoryPactChecklistLinkRepository());
  _linkContract('SqlitePactChecklistLinkRepository', () async => SqlitePactChecklistLinkRepository(await openDb()));
  _runContract('InMemoryChecklistRunRepository', () async => InMemoryChecklistRunRepository());
  _runContract('SqliteChecklistRunRepository', () async => SqliteChecklistRunRepository(await openDb()));

  group('SQLite specifics', () {
    test('getForPacts / getForShowups handle more ids than the chunk size', () async {
      final d = await openDb();
      final links = SqlitePactChecklistLinkRepository(d);
      await links.upsert(_link());
      final ids = ['pact-1', for (var i = 0; i < 1200; i++) 'x$i'];
      expect((await links.getForPacts(ids)).keys, ['pact-1']);
      final runs = SqliteChecklistRunRepository(d);
      await runs.upsertStarted(
          showupId: 'showup-1', pactId: 'pact-1', checklistId: 'c', startedAt: DateTime(2026, 3, 1));
      expect((await runs.getForShowups(['showup-1', for (var i = 0; i < 1200; i++) 'y$i'])).keys, ['showup-1']);
    });

    test('deleting the showup cascades to its run', () async {
      final d = await openDb();
      final runs = SqliteChecklistRunRepository(d);
      await runs.upsertStarted(
          showupId: 'showup-1', pactId: 'pact-1', checklistId: 'c', startedAt: DateTime(2026, 3, 1));
      await d.delete('showups', where: 'id = ?', whereArgs: ['showup-1']);
      expect(await runs.getForShowup('showup-1'), isNull);
    });

    test('deleting the pact cascades to its link', () async {
      final d = await openDb();
      final links = SqlitePactChecklistLinkRepository(d);
      await links.upsert(_link());
      await d.delete('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
      await d.delete('pacts', where: 'id = ?', whereArgs: ['pact-1']);
      expect(await links.getForPact('pact-1'), isNull);
    });

    test('a run survives updateShowup on its showup (INSERT OR REPLACE)', () async {
      final d = await openDb();
      final runs = SqliteChecklistRunRepository(d);
      await runs.upsertStarted(
          showupId: 'showup-1', pactId: 'pact-1', checklistId: 'c', startedAt: DateTime(2026, 3, 1));
      await SqliteShowupRepository(d).updateShowup(_showup.copyWith(status: ShowupStatus.done));
      expect(await runs.getForShowup('showup-1'), isNotNull);
    });

    test('a link survives a REPLACE write on its pact', () async {
      final d = await openDb();
      final links = SqlitePactChecklistLinkRepository(d);
      await links.upsert(_link());
      await d.insert('pacts', PactMapper.toRow(_pact), conflictAlgorithm: ConflictAlgorithm.replace);
      expect(await links.getForPact('pact-1'), isNotNull);
    });

    test('deleting the pact removes its runs too', () async {
      final d = await openDb();
      final runs = SqliteChecklistRunRepository(d);
      await runs.upsertStarted(
          showupId: 'showup-1', pactId: 'pact-1', checklistId: 'c', startedAt: DateTime(2026, 3, 1));
      await d.delete('showups', where: 'pact_id = ?', whereArgs: ['pact-1']);
      await d.insert('checklist_runs', {
        'showup_id': 'orphan',
        'pact_id': 'pact-1',
        'checklist_id': 'c',
        'started_at': 1,
      });
      await d.delete('pacts', where: 'id = ?', whereArgs: ['pact-1']);
      expect(await runs.getForShowup('orphan'), isNull);
    });
  });
}
