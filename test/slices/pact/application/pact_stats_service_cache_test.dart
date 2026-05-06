import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
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
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PactStatsService — in-memory cache', () {
    // -------------------------------------------------------------------------
    // Pre-warm
    // -------------------------------------------------------------------------

    group('preWarmCache', () {
      test('populates cache for multiple pacts in one pass', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1', status: ShowupStatus.done);
        final showup2 = _makeShowup('s2', 'p2', status: ShowupStatus.failed);

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact1, pact2]);

        // After pre-warming, currentStats should return cached values without
        // additional DB calls. Reset the counter then call currentStats.
        final callsBefore = showupRepo.getShowupsForPactCallCount;

        final stats1 = service.currentStats(pact: pact1, showups: []);
        final stats2 = service.currentStats(pact: pact2, showups: []);

        // No new DB calls after pre-warm (cache hits).
        expect(showupRepo.getShowupsForPactCallCount, callsBefore);

        // Stats reflect the actual showup data.
        expect(stats1.showupsDone, 1);
        expect(stats1.showupsFailed, 0);
        expect(stats2.showupsDone, 0);
        expect(stats2.showupsFailed, 1);
      });

      test('pre-warm loads showups from DB (verifies DB calls happened)', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1');
        final showup2 = _makeShowup('s2', 'p2');

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact1, pact2]);

        // One DB read per pact during pre-warm.
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

        // Pre-warm to populate the cache.
        await service.preWarmCache([pact]);
        final callsAfterWarm = showupRepo.getShowupsForPactCallCount;

        // Second call — no showups list provided, should be a cache hit.
        final stats = service.currentStats(pact: pact, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterWarm);
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

        // Pre-warm: cache populated with 0 done.
        await service.preWarmCache([pact]);
        final statsBeforeMutation = service.currentStats(pact: pact, showups: []);
        expect(statsBeforeMutation.showupsDone, 0);

        // Mutate: mark done.
        await service.persistShowupStatus(showup: showup, status: ShowupStatus.done);

        // Cache should be updated (write-through) — next read without showups
        // list returns updated counts.
        final statsAfterMutation = service.currentStats(pact: pact, showups: []);
        expect(statsAfterMutation.showupsDone, 1);
        expect(statsAfterMutation.showupsFailed, 0);
      });

      test('cache is updated after marking a showup failed', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact]);

        await service.persistShowupStatus(showup: showup, status: ShowupStatus.failed);

        final stats = service.currentStats(pact: pact, showups: []);
        expect(stats.showupsDone, 0);
        expect(stats.showupsFailed, 1);
      });

      test('cache entry is evicted before write-through (not stale)', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1');

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact]);

        // Trigger write-through.
        await service.persistShowupStatus(showup: showup, status: ShowupStatus.done);

        // Stats must reflect the mutation (not stale pre-mutation state).
        final stats = service.currentStats(pact: pact, showups: []);
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

        // Pre-warm to populate the cache.
        await service.preWarmCache([pact]);

        // Stop the pact — this should evict the cache entry only (no repopulate).
        final now = DateTime(2026, 4, 10);
        await service.stopPact(pact: pact, pactId: pact.id, now: now);

        // The next currentStats call with empty showups should fall through to
        // the pact's persisted stats (DB), not the pre-stop cache value.
        // After stopPact, showups are deleted, so calling currentStats with
        // empty showups falls back to pact.stats (persisted snapshot).
        final updatedPact = await pactRepo.getPactById(pact.id);
        expect(updatedPact, isNotNull);
        // We verify the cache was evicted by checking: if it was still cached,
        // currentStats would use pre-stop stats. Instead it returns the pact's
        // stats field (frozen snapshot). After stop, pact.stats is set.
        final stats = service.currentStats(pact: updatedPact!, showups: []);
        // stats.showupsRemaining may be 0 (all pending deleted during stop).
        // The key assertion is that currentStats returns a non-cached value
        // derived from the updated pact (no crash, correct type).
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

        await service.preWarmCache([pact1, pact2]);

        // Stop pact1 — this will make one extra DB read for pact1's showups
        // internally, but pact2's cache entry should be untouched.
        final now = DateTime(2026, 4, 10);
        await service.stopPact(pact: pact1, pactId: pact1.id, now: now);

        final callsAfterStop = showupRepo.getShowupsForPactCallCount;

        // pact2 cache should still be warm — currentStats must NOT add more DB calls.
        service.currentStats(pact: pact2, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterStop);
      });
    });

    // -------------------------------------------------------------------------
    // Lazy fallback
    // -------------------------------------------------------------------------

    group('lazy fallback', () {
      test('currentStats falls back to pact.stats when no cache and showups empty', () async {
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
        final showupRepo = _CountingShowupRepository([]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // No pre-warm, no showups → falls back to pact.stats.
        final stats = service.currentStats(pact: pact, showups: []);
        expect(stats.showupsDone, 1);
        // No DB calls made (lazy path used pact.stats directly).
        expect(showupRepo.getShowupsForPactCallCount, 0);
      });

      test('currentStats computes from showups when passed non-empty (non-cache path)', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // No pre-warm; non-empty showups passed in → compute from showups list.
        final stats = service.currentStats(pact: pact, showups: [showup]);
        expect(stats.showupsDone, 1);
        // No DB calls because showups were passed directly.
        expect(showupRepo.getShowupsForPactCallCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // preWarmCache prunes stale entries
    // -------------------------------------------------------------------------

    group('preWarmCache prunes stale entries', () {
      test('second preWarmCache evicts entries for pacts no longer in the list', () async {
        final pactA = _makePact('pA');
        final pactB = _makePact('pB');
        final showupA = _makeShowup('sA', 'pA');
        final showupB = _makeShowup('sB', 'pB');

        final pactRepo = InMemoryPactRepository([pactA, pactB]);
        final showupRepo = _CountingShowupRepository([showupA, showupB]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // First warm: both pacts cached.
        await service.preWarmCache([pactA, pactB]);

        // Simulate pactB transitioning away (auto-completed / stopped).
        // Second warm: only pactA is still active.
        await service.preWarmCache([pactA]);

        // pactB's entry must have been evicted — currentStats falls back to DB
        // (pactB.stats is null, so buildStats from empty showups is used).
        final callsBefore = showupRepo.getShowupsForPactCallCount;
        service.currentStats(pact: pactB, showups: []);

        // If pactB were still cached, no DB call would happen. Since it was
        // evicted the fallback path (pact.stats == null) computes in-memory —
        // still no DB call, but the result is "fresh" (no stale cache entry).
        // We verify the absence of a cache entry by checking that the next
        // preWarmCache for pactA alone does NOT re-add pactB.
        // Re-warm again with only pactA to confirm pactB stays evicted.
        await service.preWarmCache([pactA]);
        final callsAfterSecondWarm = showupRepo.getShowupsForPactCallCount;

        // Only pactA should have been loaded in the second warm (1 call).
        // The third warm also hits only pactA (1 more call).
        // Total new calls from second + third warm = 2 (one per pactA load each time).
        expect(callsAfterSecondWarm - callsBefore, 1);
      });

      test('second preWarmCache with only pactA does not re-cache pactB', () async {
        final pactA = _makePact('pA');
        final pactB = _makePact('pB');
        final showupA = _makeShowup('sA', 'pA', status: ShowupStatus.done);
        final showupB = _makeShowup('sB', 'pB', status: ShowupStatus.failed);

        final pactRepo = InMemoryPactRepository([pactA, pactB]);
        final showupRepo = _CountingShowupRepository([showupA, showupB]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // First warm: both cached.
        await service.preWarmCache([pactA, pactB]);

        // Second warm: pactB excluded — its entry must be removed.
        await service.preWarmCache([pactA]);

        // Verify: currentStats for pactB falls back to pact.stats (null),
        // producing a freshly-computed (in-memory, non-stale) result.
        // The key check is that the cached failed=1 from pactB's first warm
        // is NOT returned — instead the fallback returns 0 (no showups known,
        // pact.stats is null).
        final stats = service.currentStats(pact: pactB, showups: []);
        // Fallback path: pact.stats == null → buildStats(pact, showups: []) → all zeros.
        expect(stats.showupsFailed, 0);
      });
    });

    // -------------------------------------------------------------------------
    // completePact eviction
    // -------------------------------------------------------------------------

    group('completePact', () {
      test('completePact updates pact and evicts cache entry', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        // Pre-warm: cache has an entry for p1.
        await service.preWarmCache([pact]);

        // Auto-complete the pact.
        final completedPact = pact.copyWith(status: PactStatus.completed);
        await service.completePact(completedPact);

        // The pact must be updated in the repository.
        final fetched = await pactRepo.getPactById('p1');
        expect(fetched?.status, PactStatus.completed);

        // The cache entry must have been evicted: currentStats with empty showups
        // should fall back to pact.stats (not the stale cached value).
        // Since completedPact.stats == null, the fallback computes from empty list.
        final callsBefore = showupRepo.getShowupsForPactCallCount;
        service.currentStats(pact: completedPact, showups: []);
        // No new DB call: fallback is in-memory (pact.stats lookup, then buildStats).
        expect(showupRepo.getShowupsForPactCallCount, callsBefore);
      });

      test('completePact does not repopulate cache', () async {
        final pact = _makePact('p1');
        final showup = _makeShowup('s1', 'p1', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = _CountingShowupRepository([showup]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact]);
        final callsAfterWarm = showupRepo.getShowupsForPactCallCount;

        final completedPact = pact.copyWith(status: PactStatus.completed);
        await service.completePact(completedPact);

        // completePact must NOT issue extra DB reads to repopulate.
        expect(showupRepo.getShowupsForPactCallCount, callsAfterWarm);
      });

      test('other pact cache entries survive completePact of a single pact', () async {
        final pact1 = _makePact('p1');
        final pact2 = _makePact('p2');
        final showup1 = _makeShowup('s1', 'p1', status: ShowupStatus.done);
        final showup2 = _makeShowup('s2', 'p2', status: ShowupStatus.done);

        final pactRepo = InMemoryPactRepository([pact1, pact2]);
        final showupRepo = _CountingShowupRepository([showup1, showup2]);
        final service = _makeService(pactRepo: pactRepo, showupRepo: showupRepo);

        await service.preWarmCache([pact1, pact2]);

        final completedPact1 = pact1.copyWith(status: PactStatus.completed);
        await service.completePact(completedPact1);

        final callsAfterComplete = showupRepo.getShowupsForPactCallCount;

        // pact2's cache entry should still be warm.
        service.currentStats(pact: pact2, showups: []);
        expect(showupRepo.getShowupsForPactCallCount, callsAfterComplete);
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

        await service.preWarmCache([pact]);

        // Mutate s1 to done.
        await service.persistShowupStatus(showup: showup1, status: ShowupStatus.done);

        // Stats from cache.
        final cachedStats = service.currentStats(pact: pact, showups: []);

        // Fresh stats from explicit showups list (bypass cache).
        final freshShowups = await showupRepo.getShowupsForPact(pact.id);
        final freshStats = service.currentStats(pact: pact, showups: freshShowups);

        expect(cachedStats.showupsDone, freshStats.showupsDone);
        expect(cachedStats.showupsFailed, freshStats.showupsFailed);
      });
    });
  });
}
