import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart'
    show pactRepositoryProvider, showupRepositoryProvider;
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  group('PactService — in-memory (no transaction service)', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;
    late PactService service;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: null,
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

    test('createPact rolls back pact when saveShowups fails (fallback path)', () async {
      final failingShowupRepo = _ThrowingShowupRepository();
      final failService = PactService(
        pactRepository: pactRepo,
        showupRepository: failingShowupRepo,
        transactionService: null,
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
      txService = PactTransactionService(db);
      service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
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

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWith((_) => null),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(pactServiceProvider);
      final pacts = await svc.getAllPacts();
      expect(pacts, hasLength(1));
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
