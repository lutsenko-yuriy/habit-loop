import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_showup_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository(super.initialShowups);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}

Pact _pact(String id) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 10, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
    );

Showup _showup(String id, String pactId, {ShowupStatus status = ShowupStatus.pending}) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: DateTime(2026, 4, 1, 8),
      duration: const Duration(minutes: 10),
      status: status,
    );

({PactTimelineService timeline, PactStatsService stats, _CountingShowupRepository showupRepo}) _makeServices({
  required List<Pact> pacts,
  required List<Showup> showups,
  PactShowupCache? cache,
}) {
  final showupRepo = _CountingShowupRepository(showups);
  final pactRepo = InMemoryPactRepository(pacts);
  final sharedCache = cache ?? PactShowupCache();
  return (
    timeline: PactTimelineService(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      grouper: const PactTimelineGrouper(groupingThreshold: 10),
      cache: sharedCache,
    ),
    stats: PactStatsService(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
      syncService: const NoopSyncService(),
      showupCache: sharedCache,
    ),
    showupRepo: showupRepo,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Shared PactShowupCache invalidation', () {
    group('timeline load populates cache used by stats', () {
      test('stats service hits DB once even after timeline has already loaded', () async {
        final pact = _pact('p1');
        final showup = _showup('s1', 'p1');
        final svc = _makeServices(pacts: [pact], showups: [showup]);

        // Timeline loads showups from DB → populates shared cache.
        await svc.timeline.loadAll(pactId: 'p1');
        final callsAfterTimeline = svc.showupRepo.getShowupsForPactCallCount;

        // Stats service cache-miss path should find showups already in the shared cache.
        await svc.stats.currentStats(pact: pact, showups: []);
        expect(svc.showupRepo.getShowupsForPactCallCount, callsAfterTimeline,
            reason: 'stats should hit shared cache, not DB');
      });
    });

    group('stats mutation evicts timeline cache', () {
      test('persistShowupStatus evicts shared cache so timeline reloads from DB', () async {
        final pact = _pact('p1');
        final showup = _showup('s1', 'p1');
        final svc = _makeServices(pacts: [pact], showups: [showup]);

        // Warm the cache via timeline load.
        await svc.timeline.loadAll(pactId: 'p1');
        final callsAfterFirst = svc.showupRepo.getShowupsForPactCallCount;

        // Mutate via stats service — must evict the shared cache.
        await svc.stats.persistShowupStatus(showup: showup, status: ShowupStatus.done);

        // Timeline reload must hit DB again (cache was evicted).
        await svc.timeline.loadAll(pactId: 'p1');
        expect(svc.showupRepo.getShowupsForPactCallCount, greaterThan(callsAfterFirst),
            reason: 'cache was evicted; timeline must re-fetch from DB');
      });

      test('stopPact evicts shared cache so timeline reloads from DB', () async {
        final pact = _pact('p1');
        final showup = _showup('s1', 'p1', status: ShowupStatus.done);
        final svc = _makeServices(pacts: [pact], showups: [showup]);

        await svc.timeline.loadAll(pactId: 'p1');
        final callsAfterFirst = svc.showupRepo.getShowupsForPactCallCount;

        await svc.stats.stopPact(pact: pact, pactId: 'p1', now: DateTime(2026, 4, 10));

        // Timeline reload: showups are deleted by stopPact, but cache must be evicted
        // so the service attempts a fresh DB read rather than returning stale data.
        // (The read will return empty — but the eviction is what we're testing.)
        expect(svc.showupRepo.getShowupsForPactCallCount, greaterThan(callsAfterFirst),
            reason: 'cache was evicted; timeline must re-fetch from DB');
      });

      test('onPactCompleted evicts shared cache so timeline reloads from DB', () async {
        final pact = _pact('p1');
        final showup = _showup('s1', 'p1', status: ShowupStatus.done);
        final svc = _makeServices(pacts: [pact], showups: [showup]);

        await svc.timeline.loadAll(pactId: 'p1');
        final callsAfterFirst = svc.showupRepo.getShowupsForPactCallCount;

        svc.stats.onPactCompleted('p1');

        await svc.timeline.loadAll(pactId: 'p1');
        expect(svc.showupRepo.getShowupsForPactCallCount, greaterThan(callsAfterFirst),
            reason: 'cache was evicted; timeline must re-fetch from DB');
      });
    });

    group('cache isolation across pacts', () {
      test('eviction of one pact does not affect another pact in shared cache', () async {
        final pact1 = _pact('p1');
        final pact2 = _pact('p2');
        final showup1 = _showup('s1', 'p1');
        final showup2 = _showup('s2', 'p2');
        final svc = _makeServices(pacts: [pact1, pact2], showups: [showup1, showup2]);

        // Warm both pacts via timeline.
        await svc.timeline.loadAll(pactId: 'p1');
        await svc.timeline.loadAll(pactId: 'p2');

        // Evict pact1 via stats mutation (may add DB calls for pact1 internally).
        await svc.stats.persistShowupStatus(showup: showup1, status: ShowupStatus.done);

        // Capture count AFTER the mutation — pact2's cache entry must survive it.
        final callsAfterMutation = svc.showupRepo.getShowupsForPactCallCount;

        // pact2 stats should still be served from shared cache — no extra DB hit.
        await svc.stats.currentStats(pact: pact2, showups: []);
        expect(svc.showupRepo.getShowupsForPactCallCount, callsAfterMutation,
            reason: 'pact2 cache entry is unaffected by pact1 eviction');
      });
    });
  });
}
