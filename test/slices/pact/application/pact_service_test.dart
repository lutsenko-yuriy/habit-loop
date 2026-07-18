import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../infrastructure/sync/fake_sync_service.dart';

// ---------------------------------------------------------------------------
// Helper fixtures
// ---------------------------------------------------------------------------

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showups = [
  Showup(
    id: 's1',
    pactId: 'p1',
    scheduledAt: DateTime(2026, 3, 1, 8),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.pending,
  ),
  Showup(
    id: 's2',
    pactId: 'p1',
    scheduledAt: DateTime(2026, 3, 2, 8),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.pending,
  ),
];

PactDetailCache _makeCache(PactRepository pactRepo, ShowupRepository showupRepo) => PactDetailCache(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      grouper: const PactTimelineGrouper(),
    );

// ---------------------------------------------------------------------------
// In-memory path tests (delegation and fallback)
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    // Initialise sqflite_common_ffi for unit tests on macOS / Linux.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PactService — in-memory (with InMemoryPactTransactionService)', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;
    late PactService service;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );
    });

    // createPact — fallback path -------------------------------------------

    test('createPact persists both pact and showups via the in-memory fallback', () async {
      await service.createPact(_pact, _showups);

      final pacts = await pactRepo.getAllPacts();
      expect(pacts, hasLength(1));
      expect(pacts.first.id, 'p1');

      final showups = await showupRepo.getShowupsForPact('p1');
      expect(showups, hasLength(2));
    });

    test('createPact rolls back pact when saveShowups fails', () async {
      final failingShowupRepo = _ThrowingShowupRepository();
      final failTxService = InMemoryPactTransactionService(pactRepo, failingShowupRepo);
      final failService = PactService(
        pactRepository: pactRepo,
        showupRepository: failingShowupRepo,
        transactionService: failTxService,
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, failingShowupRepo),
      );

      await expectLater(
        failService.createPact(_pact, _showups),
        throwsA(isA<Exception>()),
      );

      // Pact must be rolled back — no orphan.
      final pacts = await pactRepo.getAllPacts();
      expect(pacts, isEmpty);
    });

    // Delegation tests --------------------------------------------------------

    test('getPact delegates to PactRepository.getPactById', () async {
      await pactRepo.savePact(_pact);
      final result = await service.getPact('p1');
      expect(result?.id, 'p1');
    });

    test('getPact returns null when pact does not exist', () async {
      final result = await service.getPact('missing');
      expect(result, isNull);
    });

    test('getAllPacts delegates to PactRepository.getAllPacts', () async {
      await pactRepo.savePact(_pact);
      final result = await service.getAllPacts();
      expect(result, hasLength(1));
      expect(result.first.id, 'p1');
    });

    test('getActivePacts delegates to PactRepository.getActivePacts', () async {
      await pactRepo.savePact(_pact);
      final stoppedPact = Pact(
        id: 'p2',
        habitName: _pact.habitName,
        startDate: _pact.startDate,
        endDate: _pact.endDate,
        showupDuration: _pact.showupDuration,
        schedule: _pact.schedule,
        status: PactStatus.stopped,
      );
      await pactRepo.savePact(stoppedPact);

      final result = await service.getActivePacts();
      expect(result, hasLength(1));
      expect(result.first.id, 'p1');
    });

    test('updatePact delegates to PactRepository.updatePact', () async {
      await pactRepo.savePact(_pact);
      final updated = _pact.copyWith(habitName: 'Jog');
      await service.updatePact(updated);

      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.habitName, 'Jog');
    });

    test('deletePact delegates to PactRepository.deletePact', () async {
      await pactRepo.savePact(_pact);
      await service.deletePact('p1');

      final result = await pactRepo.getAllPacts();
      expect(result, isEmpty);
    });

    // updatePact + PactDetailCache write-through --------------------------------

    test('updatePact refreshes the cache entry when pact status becomes completed', () async {
      await pactRepo.savePact(_pact);
      final completedPact = _pact.copyWith(status: PactStatus.completed);
      final cache = _makeCache(pactRepo, showupRepo);
      final serviceWithCache = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: cache,
      );

      await cache.load('p1');
      await serviceWithCache.updatePact(completedPact);

      expect(cache.peek('p1')?.pact.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.status, PactStatus.completed);
    });

    // Regression test for the HAB-174 WU0 finding: the pre-WU2 design only
    // refreshed the cache on the completed branch, so a plain note/habitName
    // edit on an active pact never wrote through — this must not regress.
    test('updatePact refreshes the cache entry for an active pact update too', () async {
      await pactRepo.savePact(_pact);
      final updatedPact = _pact.copyWith(habitName: 'Jog');
      final cache = _makeCache(pactRepo, showupRepo);
      final serviceWithCache = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: cache,
      );

      await cache.load('p1');
      await serviceWithCache.updatePact(updatedPact);

      expect(cache.peek('p1')?.pact.habitName, 'Jog',
          reason: 'updatePact must write through to the cache for every status, not just completed');
    });

    test('updatePact reuses the cached showup list instead of re-fetching from DB', () async {
      await pactRepo.savePact(_pact);
      final countingShowupRepo = _CountingShowupRepository([]);
      final cache = _makeCache(pactRepo, countingShowupRepo);
      final serviceWithCache = PactService(
        pactRepository: pactRepo,
        showupRepository: countingShowupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, countingShowupRepo),
        syncService: const NoopSyncService(),
        cache: cache,
      );

      await cache.load('p1');
      final callsAfterLoad = countingShowupRepo.getShowupsForPactCallCount;

      await serviceWithCache.updatePact(_pact.copyWith(habitName: 'Jog'));

      expect(countingShowupRepo.getShowupsForPactCallCount, callsAfterLoad,
          reason: 'updatePact never changes showups, so refreshing the cache must reuse the already-cached list');
    });
  });

  // ---------------------------------------------------------------------------
  // SQLite atomic path via PactTransactionService
  // ---------------------------------------------------------------------------

  group('PactService — SQLite atomic path (with transaction service)', () {
    late Database db;
    late SqlitePactRepository pactRepo;
    late SqliteShowupRepository showupRepo;
    late PactTransactionService txService;
    late PactService service;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
          onCreate: HabitLoopDatabase.runMigrations,
        ),
      );
      pactRepo = SqlitePactRepository(db);
      showupRepo = SqliteShowupRepository(db);
      txService = SqlitePactTransactionService(db);
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );
    });

    tearDown(() async => db.close());

    test('createPact atomically persists pact and showups', () async {
      await service.createPact(_pact, _showups);

      final pacts = await pactRepo.getAllPacts();
      expect(pacts, hasLength(1));
      expect(pacts.first.id, 'p1');

      final showups = await showupRepo.getShowupsForPact('p1');
      expect(showups, hasLength(2));
    });

    test('createPact rolls back entire transaction on duplicate showup id', () async {
      // Create a pact with a showup list that contains a duplicate showup id —
      // the second insert of 's1' will trigger ConflictAlgorithm.fail inside the
      // transaction and cause sqflite to roll back everything, including the pact.
      final showupsWithDuplicate = [
        _showups[0], // id = 's1'
        _showups[0], // id = 's1' again — duplicate will fail
      ];

      await expectLater(
        () => service.createPact(_pact, showupsWithDuplicate),
        throwsA(anything),
      );

      // The pact must NOT have been committed (transaction rolled back).
      final pacts = await pactRepo.getAllPacts();
      expect(pacts, isEmpty, reason: 'Pact should be rolled back when showup insert fails');
    });
  });

  // ---------------------------------------------------------------------------
  // Riverpod provider composition
  // ---------------------------------------------------------------------------

  group('pactServiceProvider', () {
    test('provider is accessible and composes lower-level providers', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(pactServiceProvider);
      final pacts = await svc.getAllPacts();
      expect(pacts, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Sync hook tests
  // ---------------------------------------------------------------------------

  group('sync hooks', () {
    test('uploadPact and uploadShowup called after createPact', () async {
      final fake = FakeSyncService();
      final pactRepo = InMemoryPactRepository();
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final svc = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        cache: _makeCache(pactRepo, showupRepo),
        syncService: fake,
      );

      await svc.createPact(_pact, _showups);
      // Let unawaited futures settle.
      await Future<void>.delayed(Duration.zero);

      expect(fake.uploadedPactIds, contains(_pact.id));
      expect(fake.uploadedShowupIds, containsAll(_showups.map((s) => s.id)));
    });

    test('uploadPact called after updatePact', () async {
      final fake = FakeSyncService();
      final pactRepo = InMemoryPactRepository();
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final svc = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        cache: _makeCache(pactRepo, showupRepo),
        syncService: fake,
      );

      await pactRepo.savePact(_pact);
      final updated = _pact.copyWith(habitName: 'Jog');
      await svc.updatePact(updated);
      await Future<void>.delayed(Duration.zero);

      expect(fake.uploadedPactIds, contains(_pact.id));
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _ThrowingShowupRepository extends InMemoryShowupRepository {
  @override
  Future<void> saveShowup(Showup showup) async {
    throw Exception('saveShowup failed intentionally');
  }

  @override
  Future<SaveShowupsResult> saveShowups(List<Showup> showups) async {
    throw Exception('saveShowups failed intentionally');
  }
}

/// Wraps [InMemoryShowupRepository] and counts calls to [getShowupsForPact].
class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository([super.initialShowups]);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}
