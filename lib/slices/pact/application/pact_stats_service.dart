import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Owns pact stats calculation and persistence across pact/showup mutations.
///
/// Keeping this logic in one service prevents UI view models from each
/// maintaining their own version of the `Pact.stats` invariant.
///
/// ### In-memory cache
///
/// [_statsCache] holds the most recent [PactStats] per pact ID.  The cache is
/// keyed by `pactId` and lives for the lifetime of the service (i.e. the app
/// session — Riverpod keeps the singleton alive until the container is disposed).
///
/// Cache lifecycle:
/// - **Lazy hit**: [currentStats] checks the cache first; a hit returns
///   immediately without a DB round-trip.  On a cache miss, showups are loaded
///   from the repository, stats are computed, the result is written to the
///   cache, and then returned.  Subsequent calls for the same pact are always
///   cache hits.
/// - **Write-through**: [persistShowupStatus] evicts the stale entry, then
///   [_syncStatsBestEffort] → [syncStats] → [persistStats] repopulates it.
/// - **Evict-only**: [stopPact] and [onPactCompleted] evict the entry after the
///   write because showups are deleted/irrelevant and there is nothing valid to
///   cache.
///
/// [stopPact] wraps the update-pact and delete-showups writes in a single
/// operation via [transactionService] so either both succeed or both are rolled
/// back.  Tests inject an [InMemoryPactTransactionService]; production uses
/// [SqlitePactTransactionService].
class PactStatsService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;
  final SyncService _syncService;

  /// Runtime-only stats cache; never persisted.
  final Map<String, PactStats> _statsCache = {};

  PactStatsService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    required SyncService syncService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService,
        _syncService = syncService;

  /// Returns all showups for the given pact from the showup repository.
  ///
  /// Exposed so that view models can fetch showups without depending on the
  /// [ShowupRepository] directly.
  Future<List<Showup>> loadShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);

  PactStats buildStats({
    required Pact pact,
    required List<Showup> showups,
    DateTime? endDate,
  }) {
    final effectivePact = endDate == null ? pact : pact.copyWith(endDate: endDate);
    return PactStats.compute(
      startDate: effectivePact.startDate,
      endDate: effectivePact.endDate,
      showups: showups,
      totalShowups: ShowupGenerator.countTotal(effectivePact),
    );
  }

  /// Returns stats for [pact], consulting the cache before hitting the DB.
  ///
  /// **When [showups] is non-empty:** computes fresh stats from the provided
  /// list and returns immediately.  Does NOT consult or write to the cache —
  /// the caller already has the showups loaded, so a DB round-trip is
  /// unnecessary.  Use this form when you have recently loaded showups and
  /// want to guarantee a fresh computation (e.g. inside [persistStats]).
  ///
  /// **When [showups] is empty:** triggers the lazy cache path:
  /// - *Cache hit* — returns the cached [PactStats] immediately; no DB
  ///   round-trip.
  /// - *Cache miss* — loads showups from [ShowupRepository], computes stats,
  ///   writes the result to [_statsCache], and returns.  Subsequent calls for
  ///   the same pact are guaranteed cache hits until an eviction occurs.
  ///
  /// Prefer `currentStats(pact, showups: [])` when you want the cache to be
  /// consulted or populated (e.g. in view-model `load()` calls).  Pass
  /// explicit showups only when you have already fetched them and want a fresh
  /// computation.
  Future<PactStats> currentStats({
    required Pact pact,
    required List<Showup> showups,
  }) async {
    if (showups.isNotEmpty) {
      return buildStats(pact: pact, showups: showups);
    }
    // Cache hit — return without a DB round-trip.
    final cached = _statsCache[pact.id];
    if (cached != null) return cached;

    // Cache miss: load from DB, populate cache, return.
    // This covers both active pacts on first access and stopped/completed pacts
    // whose showups have been deleted (in which case the query returns an empty
    // list and we fall back to the frozen Pact.stats snapshot if available).
    final loadedShowups = await _showupRepository.getShowupsForPact(pact.id);
    if (loadedShowups.isEmpty && pact.stats != null) {
      // No showups in DB and a frozen snapshot exists — return the snapshot
      // directly without caching it (it is already on the pact model).
      return pact.stats!;
    }
    final computed = buildStats(pact: pact, showups: loadedShowups);
    _statsCache[pact.id] = computed;
    return computed;
  }

  Future<Pact> persistStats({
    required Pact pact,
    required List<Showup> showups,
  }) async {
    final stats = buildStats(pact: pact, showups: showups);
    final updatedPact = pact.copyWith(stats: stats);
    await _pactRepository.updatePact(updatedPact);
    // Populate cache with the freshly persisted stats.
    _statsCache[pact.id] = stats;
    unawaited(_syncService.uploadPact(updatedPact));
    return updatedPact;
  }

  Future<Pact> persistInitialStatsOrRollback({
    required Pact pact,
    required List<Showup> showups,
  }) async {
    try {
      return await persistStats(pact: pact, showups: showups);
    } catch (error, stackTrace) {
      await _rollbackCreatedPact(pact.id);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Pact?> syncStats(String pactId) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) return null;

    final showups = await _showupRepository.getShowupsForPact(pactId);
    return persistStats(pact: pact, showups: showups);
  }

  /// Persists a resolved showup status and refreshes the denormalized pact
  /// stats snapshot from the same service boundary.
  ///
  /// The showup status is the source of truth for the user action. If syncing
  /// the derived pact stats fails afterwards, the primary showup update still
  /// succeeds and callers can rely on [currentStats] to recompute fresh values
  /// from showups on the next load.
  Future<Showup> persistShowupStatus({
    required Showup showup,
    required ShowupStatus status,
  }) async {
    final updatedShowup = showup.copyWith(status: status);
    await _showupRepository.updateShowup(updatedShowup);
    unawaited(_syncService.uploadShowup(updatedShowup));
    // Evict the stale cache entry *before* the write-through attempt so that
    // any read racing between the eviction and the repopulation falls back to
    // the DB rather than seeing outdated data.
    //
    // If [_syncStatsBestEffort] silently swallows an error, the cache stays
    // *empty* (not stale) for the rest of the session.  Subsequent calls to
    // [currentStats] with no showups will then trigger a lazy reload from DB.
    _statsCache.remove(updatedShowup.pactId);
    await _syncStatsBestEffort(updatedShowup.pactId);
    return updatedShowup;
  }

  /// Stops the pact atomically via [transactionService].
  ///
  /// The pact update and the showup deletion are wrapped in a single operation
  /// so either both succeed or both are rolled back.
  Future<Pact> stopPact({
    required Pact pact,
    required String pactId,
    required DateTime now,
    String? reason,
    PactStats? existingStats,
  }) async {
    final showups = await _showupRepository.getShowupsForPact(pactId);
    final stoppedDate = DateTime(now.year, now.month, now.day);
    final statsBeforeStop = existingStats ?? await currentStats(pact: pact, showups: showups);
    final updated = pact.copyWith(
      status: PactStatus.stopped,
      endDate: stoppedDate,
      stopReason: reason,
      stats: statsBeforeStop.copyWith(
        startDate: pact.startDate,
        endDate: stoppedDate,
      ),
      clearStopReason: reason == null || reason.trim().isEmpty,
    );

    await _transactionService.stopPactTransaction(
      updatedPact: updated,
      pactId: pactId,
    );

    unawaited(_syncService.uploadPact(updated));

    // Evict-only: showups are deleted by the transaction, so there is nothing
    // valid to cache.  The next read will use the frozen pact.stats snapshot.
    _statsCache.remove(pactId);

    return updated;
  }

  /// Evicts the cache entry for [pactId] after a pact has been auto-completed.
  ///
  /// Called by [PactService.updatePact] when it detects that the pact being
  /// persisted has [PactStatus.completed].  This keeps the cache consistent:
  /// a stale active-pact entry is evicted so subsequent reads fall through to
  /// the lazy-load path rather than returning pre-completion data.
  ///
  /// Does NOT persist anything — the repository write is done by the caller
  /// ([PactService.updatePact]).
  void onPactCompleted(String pactId) {
    _statsCache.remove(pactId);
  }

  Future<void> _rollbackCreatedPact(String pactId) async {
    Object? rollbackError;
    StackTrace? rollbackStackTrace;

    try {
      await _showupRepository.deleteShowupsForPact(pactId);
    } catch (error, stackTrace) {
      rollbackError = error;
      rollbackStackTrace = stackTrace;
    }

    try {
      await _pactRepository.deletePact(pactId);
    } catch (error, stackTrace) {
      rollbackError ??= error;
      rollbackStackTrace ??= stackTrace;
    }

    if (rollbackError != null && rollbackStackTrace != null) {
      Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
    }
  }

  Future<void> _syncStatsBestEffort(String pactId) async {
    try {
      await syncStats(pactId);
    } catch (_) {
      // The showup status is the source of truth for the user action. If the
      // derived pact stats snapshot fails to persist, keep the primary update
      // successful and let pact detail recompute fresh stats from showups.
    }
  }
}
