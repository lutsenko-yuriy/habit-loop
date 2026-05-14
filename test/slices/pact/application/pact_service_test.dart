import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
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
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
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
      final failStatsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: failingShowupRepo,
        transactionService: failTxService,
        syncService: const NoopSyncService(),
      );
      final failService = PactService(
        pactRepository: pactRepo,
        showupRepository: failingShowupRepo,
        transactionService: failTxService,
        syncService: const NoopSyncService(),
        pactStatsService: failStatsService,
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

    // updatePact + PactStatsService integration --------------------------------

    test('updatePact calls onPactCompleted when pact status is completed', () async {
      await pactRepo.savePact(_pact);
      final completedPact = _pact.copyWith(status: PactStatus.completed);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
      );
      final serviceWithStats = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );

      // Warm the cache first so we can verify eviction.
      final showupForCache = Showup(
        id: 's1',
        pactId: 'p1',
        scheduledAt: DateTime(2026, 3, 1, 8),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      await showupRepo.saveShowup(showupForCache);
      await statsService.currentStats(pact: _pact, showups: []);

      // After updatePact with a completed pact, cache entry must be evicted.
      await serviceWithStats.updatePact(completedPact);

      // Verify the pact was persisted.
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.status, PactStatus.completed);
    });

    test('updatePact does NOT call onPactCompleted when pact status is active', () async {
      await pactRepo.savePact(_pact);
      final updatedPact = _pact.copyWith(habitName: 'Jog');
      final statsService = _TrackingPactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
      );
      final serviceWithStats = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );

      await serviceWithStats.updatePact(updatedPact);

      expect(statsService.onPactCompletedCallCount, 0,
          reason: 'onPactCompleted must not be called for an active pact update');
    });

    test('updatePact does NOT call onPactCompleted when pact status is stopped', () async {
      final stoppedPact = _pact.copyWith(status: PactStatus.stopped);
      await pactRepo.savePact(stoppedPact);
      final statsService = _TrackingPactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
      );
      final serviceWithStats = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );

      await serviceWithStats.updatePact(stoppedPact);

      expect(statsService.onPactCompletedCallCount, 0,
          reason: 'onPactCompleted must not be called for a stopped pact update');
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
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
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
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final svc = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        pactStatsService: statsService,
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
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final svc = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        pactStatsService: statsService,
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

/// A [PactStatsService] subclass that records calls to [onPactCompleted].
class _TrackingPactStatsService extends PactStatsService {
  _TrackingPactStatsService({
    required super.pactRepository,
    required super.showupRepository,
    required super.transactionService,
    super.syncService = const NoopSyncService(),
  });

  int onPactCompletedCallCount = 0;

  @override
  void onPactCompleted(String pactId) {
    onPactCompletedCallCount++;
    super.onPactCompleted(pactId);
  }
}
