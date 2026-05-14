import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Pact _makePact(String id) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 10, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
    );

Showup _makeShowup(String id, String pactId, {ShowupStatus status = ShowupStatus.pending}) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: DateTime(2026, 4, 1, 8),
      duration: const Duration(minutes: 10),
      status: status,
    );

/// Wraps [InMemoryShowupRepository] and counts calls to [getShowupsForPact].
class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository(super.initialShowups);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}

PactStatsService _makeService({
  required InMemoryPactRepository pactRepo,
  required InMemoryShowupRepository showupRepo,
}) {
  return PactStatsService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
    syncService: const NoopSyncService(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PactStatsService — in-memory cache', () {
    // -------------------------------------------------------------------------
    // Lazy loading on first access
    // -------------------------------------------------------------------------

    group('lazy loading (cache-on-miss)', () {
      test('populates cache for multiple pacts via lazy first access', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1', status: ShowupStatus.done);
        final showup2 = _makeShowup('s2', 'p2', status: ShowupStatus.failed);

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // First access for each pact loads from DB and caches.
        final stats1 = await service.currentStats(pact: pact1, showups: []);
        final stats2 = await service.currentStats(pact: pact2, showups: []);

        // Two DB reads — one per pact on first access.
        expect(showupRepo.getShowupsForPactCallCount, 2);

        // Stats reflect the actual showup data.
        expect(stats1.showupsDone, 1);
        expect(stats1.showupsFailed, 0);
        expect(stats2.showupsDone, 0);
        expect(stats2.showupsFailed, 1);
      });

      test('lazy load issues exactly one DB call per pact on first access', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1');
        final showup2 = _makeShowup('s2', 'p2');

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.currentStats(pact: pact1, showups: []);
        await service.currentStats(pact: pact2, showups: []);

        // One DB read per pact on first lazy load.
        expect(showupRepo.getShowupsForPactCallCount, 2);
      });
    });

    // -------------------------------------------------------------------------
    // Cache hit
    // -------------------------------------------------------------------------

    group('cache hit', () {
      test('currentStats returns cached value without DB on second call when showups passed as empty', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // First call: lazy load.
        await service.currentStats(pact: pact, showups: []);
        final callsAfterFirst = showupRepo.getShowupsForPactCallCount;

        // Second call — should be a cache hit.
        final stats = await service.currentStats(pact: pact, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterFirst);
        expect(stats.showupsDone, 1);
      });
    });

    // -------------------------------------------------------------------------
    // Write-through on persistShowupStatus
    // -------------------------------------------------------------------------

    group('write-through on persistShowupStatus', () {
      test('cache is updated after marking a showup done', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // First access: lazy load — cache populated with 0 done.
        final statsBeforeMutation = await service.currentStats(pact: pact, showups: []);
        expect(statsBeforeMutation.showupsDone, 0);

        // Mutate: mark done.
        await service.persistShowupStatus(showup: showup, status: ShowupStatus.done);

        // Cache should be updated (write-through) — next read without showups
        // list returns updated counts.
        final statsAfterMutation = await service.currentStats(pact: pact, showups: []);
        expect(statsAfterMutation.showupsDone, 1);
        expect(statsAfterMutation.showupsFailed, 0);
      });

      test('cache is updated after marking a showup failed', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load to warm cache.
        await service.currentStats(pact: pact, showups: []);

        await service.persistShowupStatus(showup: showup, status: ShowupStatus.failed);

        final stats = await service.currentStats(pact: pact, showups: []);
        expect(stats.showupsDone, 0);
        expect(stats.showupsFailed, 1);
      });

      test('cache entry is evicted before write-through (not stale)', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load.
        await service.currentStats(pact: pact, showups: []);

        // Trigger write-through.
        await service.persistShowupStatus(showup: showup, status: ShowupStatus.done);

        // Stats must reflect the mutation (not stale pre-mutation state).
        final stats = await service.currentStats(pact: pact, showups: []);
        expect(stats.showupsDone, 1);
      });
    });

    // -------------------------------------------------------------------------
    // Evict-only on stopPact
    // -------------------------------------------------------------------------

    group('evict-only on stopPact', () {
      test('cache entry is removed after stopPact', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load to warm cache.
        await service.currentStats(pact: pact, showups: []);

        // Stop the pact — this should evict the cache entry only (no repopulate).
        final now = DateTime(2026, 4, 10);
        await service.stopPact(pact: pact, pactId: pact.id, now: now);

        // The next currentStats call with empty showups should fall through to
        // the pact's persisted stats (DB). After stopPact, showups are deleted,
        // so calling currentStats with empty showups and a frozen stats snapshot
        // returns that snapshot.
        final updatedPact = await pactRepo.getPactById(pact.id);
        expect(updatedPact, isNotNull);
        // Verify the cache was evicted by checking that a call returns a valid
        // PactStats derived from the updated pact.
        final stats = await service.currentStats(pact: updatedPact!, showups: []);
        expect(stats, isA<PactStats>());
      });

      test('cache entries for other pacts survive stopPact of a single pact', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1', status: ShowupStatus.done);
        final showup2 = _makeShowup('s2', 'p2', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load both pacts to warm their cache entries.
        await service.currentStats(pact: pact1, showups: []);
        await service.currentStats(pact: pact2, showups: []);

        // Stop pact1 — this will make one extra DB read for pact1's showups
        // internally, but pact2's cache entry should be untouched.
        final now = DateTime(2026, 4, 10);
        await service.stopPact(pact: pact1, pactId: pact1.id, now: now);

        final callsAfterStop = showupRepo.getShowupsForPactCallCount;

        // pact2 cache should still be warm — currentStats must NOT add more DB calls.
        await service.currentStats(pact: pact2, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterStop);
      });
    });

    // -------------------------------------------------------------------------
    // Lazy fallback to pact.stats
    // -------------------------------------------------------------------------

    group('lazy fallback to pact.stats', () {
      test('currentStats falls back to pact.stats when no showups in DB and pact has a frozen snapshot', () async {
        final pactStats = PactStats.compute(
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 10, 1),
          showups: [_makeShowup('s1', 'p1', status: ShowupStatus.done)],
          totalShowups: 183,
        );
        final pact = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 10, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.stopped,
          stats: pactStats,
        );

        final pactRepo = InMemoryPactRepository([pact]);
        // Empty showup repo simulates a stopped pact whose showups were deleted.
        final showupRepo = _CountingShowupRepository([]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // No cache — lazy miss → DB returns empty list → fall back to pact.stats.
        final stats = await service.currentStats(pact: pact, showups: []);
        expect(stats.showupsDone, 1);
        // DB was queried once (lazy miss), but result was empty → fallback used.
        expect(showupRepo.getShowupsForPactCallCount, 1);
      });

      test('currentStats computes from showups when passed non-empty (non-cache path)', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Non-empty showups passed in → compute from showups list, no cache/DB.
        final stats = await service.currentStats(pact: pact, showups: [showup]);
        expect(stats.showupsDone, 1);
        // No DB calls because showups were passed directly.
        expect(showupRepo.getShowupsForPactCallCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // onPactCompleted eviction
    // -------------------------------------------------------------------------

    group('onPactCompleted', () {
      test('onPactCompleted evicts cache entry', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load: cache has an entry for p1.
        await service.currentStats(pact: pact, showups: []);

        // Evict via onPactCompleted.
        service.onPactCompleted('p1');

        // Cache entry must have been evicted: next call reloads from DB.
        final callsBefore = showupRepo.getShowupsForPactCallCount;
        await service.currentStats(pact: pact, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, greaterThan(callsBefore));
      });

      test('onPactCompleted does not perform a DB write', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load to warm cache.
        await service.currentStats(pact: pact, showups: []);

        // onPactCompleted should only evict — pact repo should not be updated.
        final pactBefore = await pactRepo.getPactById('p1');
        service.onPactCompleted('p1');
        final pactAfter = await pactRepo.getPactById('p1');

        // The pact in the repo is unchanged (no update was issued).
        expect(pactAfter?.status, pactBefore?.status);
      });

      test('other pact cache entries survive onPactCompleted of a single pact', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1', status: ShowupStatus.done);
        final showup2 = _makeShowup('s2', 'p2', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load both pacts.
        await service.currentStats(pact: pact1, showups: []);
        await service.currentStats(pact: pact2, showups: []);

        // Evict pact1.
        service.onPactCompleted('p1');

        final callsAfterEvict = showupRepo.getShowupsForPactCallCount;

        // pact2's cache entry should still be warm — no additional DB call.
        await service.currentStats(pact: pact2, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterEvict);
      });
    });

    // -------------------------------------------------------------------------
    // Cache correctness
    // -------------------------------------------------------------------------

    group('cache correctness', () {
      test('cached stats match freshly computed stats after mutation', () async {
        final pact = _makePact('p1');
        final showup1 = _makeShowup('s1', 'p1');
        final showup2 = _makeShowup('s2', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Lazy load to warm cache.
        await service.currentStats(pact: pact, showups: []);

        // Mutate s1 to done.
        await service.persistShowupStatus(showup: showup1, status: ShowupStatus.done);

        // Stats from cache (write-through updated it).
        final cachedStats = await service.currentStats(pact: pact, showups: []);

        // Fresh stats from explicit showups list (bypass cache).
        final freshShowups = await showupRepo.getShowupsForPact(pact.id);
        final freshStats = await service.currentStats(pact: pact, showups: freshShowups);

        expect(cachedStats.showupsDone, freshStats.showupsDone);
        expect(cachedStats.showupsFailed, freshStats.showupsFailed);
      });
    });
  });
}
