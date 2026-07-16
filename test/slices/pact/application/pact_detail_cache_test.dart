import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _schedule = DailySchedule(timeOfDay: Duration(hours: 8));
final _start = DateTime(2024, 1, 1);
final _end = DateTime(2024, 3, 31);

Pact _pact({
  String id = 'p1',
  PactStatus status = PactStatus.active,
  DateTime? createdAt,
  DateTime? stoppedAt,
  String? stopReason,
  PactStats? stats,
}) =>
    Pact(
      id: id,
      habitName: 'Meditate',
      startDate: _start,
      endDate: _end,
      showupDuration: const Duration(minutes: 30),
      schedule: _schedule,
      status: status,
      createdAt: createdAt,
      stoppedAt: stoppedAt,
      stopReason: stopReason,
      stats: stats,
    );

Showup _showup(
  String id,
  DateTime at, {
  String pactId = 'p1',
  ShowupStatus status = ShowupStatus.done,
  String? note,
}) =>
    Showup(
      id: id,
      pactId: pactId,
      scheduledAt: at,
      duration: const Duration(minutes: 30),
      status: status,
      note: note,
    );

/// Wraps [InMemoryPactRepository] and counts calls to [getPactById].
class _CountingPactRepository extends InMemoryPactRepository {
  _CountingPactRepository(super.pacts);

  int getPactByIdCallCount = 0;

  @override
  Future<Pact?> getPactById(String id) async {
    getPactByIdCallCount++;
    return super.getPactById(id);
  }
}

/// Wraps [InMemoryShowupRepository] and counts calls to [getShowupsForPact].
class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository(super.showups);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}

PactDetailCache _cache({
  List<Pact>? pacts,
  List<Showup>? showups,
  PactTimelineGrouper? grouper,
}) =>
    PactDetailCache(
      pactRepository: _CountingPactRepository(pacts ?? []),
      showupRepository: _CountingShowupRepository(showups ?? []),
      grouper: grouper ?? const PactTimelineGrouper(groupingThreshold: 10),
    );

/// Canonical, structurally-comparable representation of a milestone — used
/// because the milestone classes have no `==` override. Dart records are
/// value-equal, so two milestones with the same runtime type and fields
/// compare equal via this projection.
Object _describe(PactTimelineMilestone m) => switch (m) {
      PactCreatedMilestone(:final sortAt, :final habitName, :final schedule, :final plannedEndDate) => (
          'created',
          sortAt,
          habitName,
          schedule,
          plannedEndDate,
        ),
      ShowupStreakMilestone(:final sortAt, :final outcome, :final count, :final firstAt, :final lastAt) => (
          'streak',
          sortAt,
          outcome,
          count,
          firstAt,
          lastAt,
        ),
      SingleShowupMilestone(:final sortAt, :final showupId, :final outcome, :final scheduledAt) => (
          'single',
          sortAt,
          showupId,
          outcome,
          scheduledAt,
        ),
      ShowupGroupMilestone(
        :final sortAt,
        :final total,
        :final doneCount,
        :final failedCount,
        :final firstAt,
        :final lastAt
      ) =>
        ('group', sortAt, total, doneCount, failedCount, firstAt, lastAt),
      NotedShowupMilestone(:final sortAt, :final showupId, :final scheduledAt, :final outcome, :final note) => (
          'noted',
          sortAt,
          showupId,
          scheduledAt,
          outcome,
          note,
        ),
      CurrentStateMilestone(:final sortAt, :final nextScheduledAt, :final showupsRemaining, :final plannedEndDate) => (
          'current',
          sortAt,
          nextScheduledAt,
          showupsRemaining,
          plannedEndDate,
        ),
      PactConcludedMilestone(:final sortAt, :final concludedAt, :final finalStatus, :final note) => (
          'concluded',
          sortAt,
          concludedAt,
          finalStatus,
          note,
        ),
    };

List<Object> _describeAll(List<PactTimelineMilestone> milestones) => milestones.map(_describe).toList();

void main() {
  group('PactDetailCache — cache miss', () {
    test('fetches pact and showups exactly once and populates the cache', () async {
      final pactRepo = _CountingPactRepository([_pact()]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      final bundle = await cache.load('p1', now: DateTime(2024, 2, 1));

      expect(pactRepo.getPactByIdCallCount, 1);
      expect(showupRepo.getShowupsForPactCallCount, 1);
      expect(bundle.pact.id, 'p1');
      expect(cache.peek('p1'), same(bundle));
    });

    test('throws ArgumentError when the pact does not exist', () async {
      final cache = _cache(pacts: []);
      expect(() => cache.load('missing'), throwsArgumentError);
    });
  });

  group('PactDetailCache — cache hit', () {
    test('returns the same bundle without any further DB calls', () async {
      final pactRepo = _CountingPactRepository([_pact()]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      final first = await cache.load('p1', now: DateTime(2024, 2, 1));
      final callsAfterFirst = (pactRepo.getPactByIdCallCount, showupRepo.getShowupsForPactCallCount);

      final second = await cache.load('p1', now: DateTime(2024, 2, 1));

      expect(identical(first, second), isTrue);
      expect(pactRepo.getPactByIdCallCount, callsAfterFirst.$1);
      expect(showupRepo.getShowupsForPactCallCount, callsAfterFirst.$2);
    });
  });

  group('PactDetailCache — peek', () {
    test('returns null synchronously on a cache miss', () {
      final cache = _cache(pacts: [_pact()]);
      expect(cache.peek('p1'), isNull);
    });

    test('returns the cached bundle synchronously after a load', () async {
      final cache = _cache(pacts: [_pact()], showups: [_showup('s1', DateTime(2024, 1, 5))]);
      final bundle = await cache.load('p1', now: DateTime(2024, 2, 1));
      expect(cache.peek('p1'), same(bundle));
    });
  });

  group('PactDetailCache — refresh (write-through)', () {
    test('overwrites the cache entry unconditionally', () async {
      final pact = _pact();
      final pactRepo = _CountingPactRepository([pact]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      await cache.load('p1', now: DateTime(2024, 2, 1));

      final newShowups = [
        _showup('s1', DateTime(2024, 1, 5), status: ShowupStatus.done),
        _showup('s2', DateTime(2024, 1, 6), status: ShowupStatus.done),
      ];
      final refreshed = await cache.refresh('p1', pact: pact, showups: newShowups, now: DateTime(2024, 2, 1));

      expect(refreshed.stats.showupsDone, 2);
      expect(cache.peek('p1'), same(refreshed));
    });

    test('skips the DB fetch entirely when both pact and showups are passed in', () async {
      final pact = _pact();
      final pactRepo = _CountingPactRepository([pact]);
      final showupRepo = _CountingShowupRepository([]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      await cache.refresh('p1', pact: pact, showups: [_showup('s1', DateTime(2024, 1, 5))], now: DateTime(2024, 2, 1));

      expect(pactRepo.getPactByIdCallCount, 0);
      expect(showupRepo.getShowupsForPactCallCount, 0);
    });

    test('reuses the previously cached showup list when only pact is passed (no extra DB fetch)', () async {
      final pact = _pact();
      final pactRepo = _CountingPactRepository([pact]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5), status: ShowupStatus.done)]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      await cache.load('p1', now: DateTime(2024, 2, 1));
      final callsAfterLoad = showupRepo.getShowupsForPactCallCount;

      final editedPact = pact.copyWith(habitName: 'Meditate daily');
      final refreshed = await cache.refresh('p1', pact: editedPact, now: DateTime(2024, 2, 1));

      // No extra showup fetch — the cached list (1 done showup) was reused.
      expect(showupRepo.getShowupsForPactCallCount, callsAfterLoad);
      expect(refreshed.stats.showupsDone, 1);
      expect(refreshed.pact.habitName, 'Meditate daily');
    });

    test('fetches from DB when neither pact nor showups are passed and nothing is cached yet', () async {
      final pact = _pact();
      final pactRepo = _CountingPactRepository([pact]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      final refreshed = await cache.refresh('p1', now: DateTime(2024, 2, 1));

      expect(pactRepo.getPactByIdCallCount, 1);
      expect(showupRepo.getShowupsForPactCallCount, 1);
      expect(refreshed.pact.id, 'p1');
    });
  });

  group('PactDetailCache — evict', () {
    test('clears the entry without repopulating', () async {
      final pactRepo = _CountingPactRepository([_pact()]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      await cache.load('p1', now: DateTime(2024, 2, 1));
      cache.evict('p1');

      expect(cache.peek('p1'), isNull);
      expect(pactRepo.getPactByIdCallCount, 1);
      expect(showupRepo.getShowupsForPactCallCount, 1);
    });

    test('a subsequent load re-fetches from DB', () async {
      final pactRepo = _CountingPactRepository([_pact()]);
      final showupRepo = _CountingShowupRepository([_showup('s1', DateTime(2024, 1, 5))]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(groupingThreshold: 10),
      );

      await cache.load('p1', now: DateTime(2024, 2, 1));
      cache.evict('p1');
      await cache.load('p1', now: DateTime(2024, 2, 1));

      expect(pactRepo.getPactByIdCallCount, 2);
      expect(showupRepo.getShowupsForPactCallCount, 2);
    });
  });

  group('PactDetailCache — frozen-snapshot fallback', () {
    test('uses pact.stats when the showup list is empty and a frozen snapshot exists', () async {
      final frozenStats = PactStats.compute(
        startDate: _start,
        endDate: DateTime(2024, 2, 10),
        showups: [_showup('s1', DateTime(2024, 1, 5), status: ShowupStatus.done)],
        totalShowups: 40,
      );
      final stoppedPact = _pact(
        status: PactStatus.stopped,
        stoppedAt: DateTime(2024, 2, 10),
        stats: frozenStats,
      );
      final cache = _cache(pacts: [stoppedPact], showups: []);

      final bundle = await cache.load('p1', now: DateTime(2024, 2, 15));

      expect(bundle.stats, frozenStats);
      // timelinePage is still built normally from the empty showup list.
      expect(bundle.timelinePage.milestones, isEmpty);
      expect(bundle.timelinePage.tailStartIndex, 0);
      expect(bundle.timelinePage.anchorEnd, isA<PactConcludedMilestone>());
    });

    test('recomputes normally when showups are empty but pact.stats is null', () async {
      final cache = _cache(pacts: [_pact(stats: null)], showups: []);
      final bundle = await cache.load('p1', now: DateTime(2024, 2, 15));

      // No frozen snapshot to fall back to — recomputed from an empty list.
      expect(bundle.stats.showupsDone, 0);
      expect(bundle.stats.showupsFailed, 0);
      expect(bundle.stats.currentStreak, 0);
    });
  });

  group('PactDetailCache — golden equivalence vs PactStats.compute + PactTimelineGrouper.group', () {
    Future<void> expectGoldenMatch({
      required List<Showup> showups,
      required PactTimelineGrouper grouper,
      required DateTime now,
      PactStatus status = PactStatus.active,
    }) async {
      final pact = _pact(status: status);
      final cache = PactDetailCache(
        pactRepository: _CountingPactRepository([pact]),
        showupRepository: _CountingShowupRepository(showups),
        grouper: grouper,
      );

      final bundle = await cache.load('p1', now: now);

      final sorted = [...showups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final expectedStats = PactStats.compute(
        startDate: pact.startDate,
        endDate: pact.endDate,
        showups: sorted,
        totalShowups: ShowupGenerator.countTotal(pact),
      );
      final expectedGrouped = grouper.group(sorted, now: now);

      expect(bundle.stats, expectedStats, reason: 'stats mismatch for $showups');
      expect(
        _describeAll(bundle.timelinePage.milestones),
        _describeAll(expectedGrouped.milestones),
        reason: 'milestones mismatch for $showups',
      );
      expect(bundle.timelinePage.tailStartIndex, expectedGrouped.tailStartIndex);
    }

    test('mixed done/failed/pending run, no notes, tail zone at the end', () async {
      final showups = [
        for (var i = 0; i < 12; i++)
          _showup(
            's$i',
            DateTime(2024, 1, i + 1, 8),
            status: i.isEven ? ShowupStatus.done : ShowupStatus.failed,
          ),
      ];
      await expectGoldenMatch(
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 10, noGroupingTailPeriodInDays: 3),
        now: DateTime(2024, 1, 13),
      );
    });

    test('long uniform-done streak with a trailing pending run (crosses tail-zone boundary)', () async {
      final showups = [
        for (var i = 0; i < 20; i++) _showup('d$i', DateTime(2024, 1, i + 1, 8), status: ShowupStatus.done),
        for (var i = 0; i < 5; i++) _showup('p$i', DateTime(2024, 1, 21 + i, 8), status: ShowupStatus.pending),
      ];
      await expectGoldenMatch(
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 5, noGroupingTailPeriodInDays: 7),
        now: DateTime(2024, 1, 25),
      );
    });

    test('showups with notes interleaved across the grouping window', () async {
      final showups = [
        for (var i = 0; i < 10; i++)
          _showup(
            'n$i',
            DateTime(2024, 2, i + 1, 8),
            status: i % 3 == 0 ? ShowupStatus.failed : ShowupStatus.done,
            note: i % 4 == 0 ? 'note-$i' : null,
          ),
      ];
      await expectGoldenMatch(
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 3, noGroupingTailPeriodInDays: 5),
        now: DateTime(2024, 2, 15),
        status: PactStatus.completed,
      );
    });

    test('streak crossing the tail-zone boundary buckets identically on both paths', () async {
      // A single unbroken run of 'done' spanning both sides of the cutoff —
      // exercises TailZone.contains at the boundary for both stats streak
      // counting and the grouper's tail/non-tail bucketing.
      final now = DateTime(2024, 3, 10);
      final showups = [
        for (var i = 0; i < 15; i++) _showup('r$i', DateTime(2024, 3, 1 + i, 8), status: ShowupStatus.done),
      ];
      await expectGoldenMatch(
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 4, noGroupingTailPeriodInDays: 7),
        now: now,
      );
    });

    test('stopped pact with mixed history', () async {
      final showups = [
        _showup('a', DateTime(2024, 1, 5), status: ShowupStatus.done),
        _showup('b', DateTime(2024, 1, 6), status: ShowupStatus.failed),
        _showup('c', DateTime(2024, 1, 7), status: ShowupStatus.done, note: 'felt good'),
        _showup('d', DateTime(2024, 1, 20), status: ShowupStatus.pending),
      ];
      await expectGoldenMatch(
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 2, noGroupingTailPeriodInDays: 10),
        now: DateTime(2024, 1, 25),
        status: PactStatus.stopped,
      );
    });
  });
}
