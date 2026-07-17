import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_bundle.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';

/// Session-scoped, injectable, single population/write-through entry point
/// for a pact's stats + timeline + metadata (HAB-174).
///
/// Replaces the earlier separate `PactTimelineCache` and `PactStatsService`'s
/// private stats cache — that two-cache design (HAB-126, canceled) let a
/// shared read path (`syncStats`) bypass the timeline cache and desync the
/// two. This class is the single place a pact's showups are fetched and
/// computed from; every mutation path must go through [refresh]/[evict] here
/// rather than maintaining a second, bypassable cache.
///
/// No consumers are wired onto this cache yet (HAB-174 WU1) — `PactStatsService`,
/// `PactDetailViewModel`, and `PactTimelineViewModel` are wired in WU2/WU3.
class PactDetailCache {
  PactDetailCache({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTimelineGrouper grouper,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _grouper = grouper;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTimelineGrouper _grouper;

  final Map<String, PactDetailBundle> _bundles = {};

  // Parallel to _bundles, keyed the same way — retained so refresh() can
  // reuse the previously-fetched showup list when only the pact changed
  // (e.g. a note edit), without a redundant DB round-trip.
  final Map<String, List<Showup>> _showups = {};

  /// Cache hit: returns immediately, no DB call, no recompute.
  /// Cache miss: fetches [Pact] + showups once, computes the bundle, stores,
  /// and returns it. Throws [ArgumentError] if the pact doesn't exist (same
  /// contract `PactTimelineService.loadAll` has today).
  Future<PactDetailBundle> load(String pactId, {DateTime? now}) async {
    final cached = _bundles[pactId];
    if (cached != null) return cached;

    final pact = await _fetchPact(pactId);
    final showups = await _showupRepository.getShowupsForPact(pactId);
    return _populate(pactId, pact: pact, showups: showups, now: now);
  }

  /// Synchronous, cache-only — no fetch. Used to seed the Timeline title from
  /// `build()` without a forwarded navigation argument.
  PactDetailBundle? peek(String pactId) => _bundles[pactId];

  /// The one write-through entry point. Skips the corresponding DB fetch for
  /// whichever of [pact]/[showups] the caller already has in hand.
  ///
  /// [reuseCachedShowups] must be set explicitly to reuse the previously
  /// cached showup list instead of re-fetching — safe only when the caller
  /// knows the pact's showups did not change (e.g. a note or habit-name
  /// edit). Defaults to `false`: without an explicit [showups] list, a bare
  /// `refresh(pactId)` always re-fetches from the DB, so a caller that
  /// forgets to pass the fresh showups after a status change can never
  /// silently serve a stale, pre-change cached list — this was a latent
  /// version of the exact stale-cache bug this class exists to prevent
  /// (HAB-126).
  ///
  /// Recomputes and overwrites the cache entry unconditionally.
  Future<PactDetailBundle> refresh(
    String pactId, {
    Pact? pact,
    List<Showup>? showups,
    bool reuseCachedShowups = false,
    DateTime? now,
  }) async {
    final effectivePact = pact ?? await _fetchPact(pactId);
    final effectiveShowups =
        showups ?? (reuseCachedShowups ? _showups[pactId] : null) ?? await _showupRepository.getShowupsForPact(pactId);
    return _populate(pactId, pact: effectivePact, showups: effectiveShowups, now: now);
  }

  /// Evict-only — for when there is nothing valid left to cache (e.g. after
  /// `stopPactTransaction` deletes the pact's showups). The next [load] miss
  /// falls back to the frozen `pact.stats` snapshot.
  void evict(String pactId) {
    _bundles.remove(pactId);
    _showups.remove(pactId);
  }

  Future<Pact> _fetchPact(String pactId) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) throw ArgumentError('Pact $pactId not found');
    return pact;
  }

  PactDetailBundle _populate(
    String pactId, {
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
  }) {
    final bundle = _computeBundle(pact: pact, showups: showups, now: now ?? DateTime.now());
    _bundles[pactId] = bundle;
    _showups[pactId] = showups;
    return bundle;
  }

  // Bundle computation — two-loop fallback (documented, no sign-off needed).
  //
  // The plan's primary approach called for a single forward pass that fuses
  // PactStats.compute's done/failed/streak accumulation with
  // PactTimelineGrouper.group's tail/non-tail bucketing, then feeding the
  // pre-bucketed lists into the grouper's existing (private) _processNonTail/
  // _processTail passes. That fusion is not reachable from this file without
  // widening PactTimelineGrouper's API: `_processNonTail`/`_processTail` are
  // library-private to pact_timeline_grouper.dart, and that file is outside
  // this WU's approved scope (pact_detail_bundle.dart, pact_detail_cache.dart,
  // pact_detail_cache_test.dart only). Rather than touching the grouper file
  // to expose them, this takes the plan's explicit documented fallback:
  // call the two existing, unmodified pure functions back-to-back on the same
  // sorted showup list. This still satisfies the ticket's actual requirement
  // (one DB fetch, one cache, one write-through path) — it just costs two
  // O(n) passes over an in-memory list instead of one.
  PactDetailBundle _computeBundle({
    required Pact pact,
    required List<Showup> showups,
    required DateTime now,
  }) {
    final sorted = [...showups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // Frozen-snapshot fallback: a cache miss with an empty showup list (a
    // stopped/completed pact whose showups were deleted by
    // stopPactTransaction) uses the frozen Pact.stats snapshot instead of
    // recomputing from nothing, which would zero everything out. The
    // timelinePage below is still built normally from the empty list —
    // _buildAnchorEnd already handles non-active pact status via
    // PactConcludedMilestone regardless of showup count.
    final stats = sorted.isEmpty && pact.stats != null
        ? pact.stats!
        : PactStats.compute(
            startDate: pact.startDate,
            endDate: pact.endDate,
            showups: sorted,
            totalShowups: ShowupGenerator.countTotal(pact),
          );

    final grouped = _grouper.group(sorted, now: now);
    final timelinePage = PactTimelinePage(
      anchorStart: _buildAnchorStart(pact),
      anchorEnd: _buildAnchorEnd(pact: pact, showups: sorted, now: now),
      milestones: grouped.milestones,
      tailPeriodInDays: _grouper.noGroupingTailPeriodInDays,
      tailStartIndex: grouped.tailStartIndex,
    );

    return PactDetailBundle(pact: pact, stats: stats, timelinePage: timelinePage);
  }

  // Mirrors PactTimelineService._buildAnchorStart — duplicated here rather
  // than shared because PactTimelineService is deleted in WU3 once
  // PactTimelineViewModel is wired onto this cache instead.
  PactCreatedMilestone _buildAnchorStart(Pact pact) => PactCreatedMilestone(
        sortAt: pact.createdAt ?? pact.startDate,
        habitName: pact.habitName,
        schedule: pact.schedule,
        plannedEndDate: pact.endDate,
      );

  // Mirrors PactTimelineService._buildAnchorEnd — see _buildAnchorStart.
  PactTimelineMilestone _buildAnchorEnd({
    required Pact pact,
    required List<Showup> showups,
    required DateTime now,
  }) {
    if (pact.status == PactStatus.active) {
      final pending = showups.where((s) => s.status == ShowupStatus.pending);
      final done = showups.where((s) => s.status == ShowupStatus.done).length;
      final failed = showups.where((s) => s.status == ShowupStatus.failed).length;
      final total = ShowupGenerator.countTotal(pact);
      return CurrentStateMilestone(
        sortAt: now,
        nextScheduledAt: pending.firstOrNull?.scheduledAt,
        showupsRemaining: (total - done - failed).clamp(0, total),
        plannedEndDate: pact.endDate,
      );
    }
    final concludedAt = pact.stoppedAt ?? pact.endDate;
    return PactConcludedMilestone(
      sortAt: concludedAt,
      concludedAt: concludedAt,
      finalStatus: pact.status,
      note: pact.stopReason,
    );
  }
}
