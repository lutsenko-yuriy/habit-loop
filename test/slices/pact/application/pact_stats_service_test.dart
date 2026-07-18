import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/sync/fake_sync_service.dart';

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

PactDetailCache _makeCache(InMemoryPactRepository pactRepo, InMemoryShowupRepository showupRepo) => PactDetailCache(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      grouper: const PactTimelineGrouper(),
    );

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 4, 1),
  endDate: DateTime(2026, 10, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _pendingShowup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 4, 1, 8),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

void main() {
  _syncHookTests();

  group('PactStatsService.currentStats — lazy cache-on-miss', () {
    test('first call with empty showups loads from DB and populates cache', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _CountingShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // First call with empty showups — no cached entry yet → should hit DB.
      final stats = await service.currentStats(pact: _pact, showups: []);

      expect(showupRepo.getShowupsForPactCallCount, 1, reason: 'First miss must load from DB');
      expect(stats, isNotNull);
    });

    test('second call with empty showups is a cache hit and does not hit DB again', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _CountingShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // Warm the cache via the first call.
      await service.currentStats(pact: _pact, showups: []);
      final callsAfterFirst = showupRepo.getShowupsForPactCallCount;

      // Second call — should be a cache hit.
      await service.currentStats(pact: _pact, showups: []);

      expect(showupRepo.getShowupsForPactCallCount, callsAfterFirst,
          reason: 'Second call must be a cache hit — no additional DB round-trip');
    });

    test('cache is populated after first lazy load and reflects loaded showups', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _CountingShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // First call loads 1 pending showup from DB.
      final stats = await service.currentStats(pact: _pact, showups: []);
      // Second call reads from cache — result must be consistent.
      final statsAgain = await service.currentStats(pact: _pact, showups: []);

      expect(stats.showupsDone, statsAgain.showupsDone);
      expect(stats.showupsFailed, statsAgain.showupsFailed);
    });

    test('currentStats with non-empty showups bypasses cache and does not hit DB', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _CountingShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // Passing showups directly always computes fresh — no DB needed.
      await service.currentStats(pact: _pact, showups: [_pendingShowup]);

      expect(showupRepo.getShowupsForPactCallCount, 0,
          reason: 'Caller-provided showups must bypass the cache and DB entirely');
    });

    test('stopPact evicts the cache entry so the next currentStats reloads from DB', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _CountingShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // Warm the cache.
      await service.currentStats(pact: _pact, showups: []);
      final callsAfterWarm = showupRepo.getShowupsForPactCallCount;

      await service.stopPact(pact: _pact, pactId: _pact.id, now: DateTime(2026, 5, 1));

      // Next call must go back to DB (cache miss after eviction).
      await service.currentStats(pact: _pact, showups: []);
      expect(showupRepo.getShowupsForPactCallCount, greaterThan(callsAfterWarm),
          reason: 'After stopPact evicts the cache, the next currentStats call must reload from DB');
    });
  });

  group('PactStatsService.persistShowupStatus', () {
    test('updates the showup and refreshes pact stats from one service boundary', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.done,
      );

      expect(updatedShowup.status, ShowupStatus.done);

      final persistedShowup = await showupRepo.getShowupById(_pendingShowup.id);
      expect(persistedShowup?.status, ShowupStatus.done);

      final persistedPact = await pactRepo.getPactById(_pact.id);
      final totalShowups = ShowupGenerator.countTotal(persistedPact!);
      expect(persistedPact.stats?.showupsDone, 1);
      expect(persistedPact.stats?.showupsFailed, 0);
      expect(persistedPact.stats?.showupsRemaining, totalShowups - 1);
    });

    test('keeps the showup update when pact stats sync fails', () async {
      final pactRepo = _ThrowingOnUpdatePactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.failed,
      );

      expect(updatedShowup.status, ShowupStatus.failed);

      final persistedShowup = await showupRepo.getShowupById(_pendingShowup.id);
      expect(persistedShowup?.status, ShowupStatus.failed);
    });

    test('persists redeemable=false when caller sets it explicitly', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.failed,
        redeemable: false,
      );

      expect(updatedShowup.redeemable, isFalse);

      final persisted = await showupRepo.getShowupById(_pendingShowup.id);
      expect(persisted?.redeemable, isFalse);
    });

    test('preserves existing redeemable when param is omitted', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: _makeCache(pactRepo, showupRepo),
      );

      // _pendingShowup has redeemable=true (default); omitting param must not change it.
      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.done,
      );

      expect(updatedShowup.redeemable, isTrue);
    });
  });
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

// ---------------------------------------------------------------------------
// Sync hook tests
// ---------------------------------------------------------------------------

void _syncHookTests() {
  group('PactStatsService — sync hooks', () {
    test('uploadPact called after persistStats', () async {
      final fake = FakeSyncService();
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: fake,
        cache: _makeCache(pactRepo, showupRepo),
      );

      await service.persistStats(pact: _pact, showups: [_pendingShowup]);
      await Future<void>.delayed(Duration.zero);

      expect(fake.uploadedPactIds, contains(_pact.id));
    });

    test('uploadShowup called after persistShowupStatus', () async {
      final fake = FakeSyncService();
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: fake,
        cache: _makeCache(pactRepo, showupRepo),
      );

      await service.persistShowupStatus(showup: _pendingShowup, status: ShowupStatus.done);
      await Future<void>.delayed(Duration.zero);

      expect(fake.uploadedShowupIds, contains(_pendingShowup.id));
    });

    test('uploadPact called after stopPact', () async {
      final fake = FakeSyncService();
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        syncService: fake,
        cache: _makeCache(pactRepo, showupRepo),
      );

      await service.stopPact(pact: _pact, pactId: _pact.id, now: DateTime(2026, 5, 1));
      await Future<void>.delayed(Duration.zero);

      expect(fake.uploadedPactIds, contains(_pact.id));
    });
  });
}
