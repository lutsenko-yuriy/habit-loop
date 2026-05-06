import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
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
/// - **Pre-warm**: [preWarmCache] loads all active pacts in one pass and fills
///   the cache before any individual screen opens.
/// - **Lazy hit**: [currentStats] checks the cache first; a hit returns
///   immediately without a DB round-trip.
/// - **Write-through**: [persistShowupStatus] evicts the stale entry, then
///   [_syncStatsBestEffort] → [syncStats] → [persistStats] repopulates it.
/// - **Evict-only**: [stopPact] evicts the entry after the transaction because
///   showups are deleted and there is nothing valid to cache.
///
/// [stopPact] wraps the update-pact and delete-showups writes in a single
/// operation via [transactionService] so either both succeed or both are rolled
/// back. Tests inject an [InMemoryPactTransactionService]; production uses
/// [SqlitePactTransactionService].
class PactStatsService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;

  /// Runtime-only stats cache; never persisted.
  final Map<String, PactStats> _statsCache = {};

  PactStatsService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService;

  /// Returns all showups for the given pact from the showup repository.
  ///
  /// Exposed so that view models can fetch showups without depending on the
  /// [ShowupRepository] directly.
  Future<List<Showup>> loadShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);

  /// Pre-warms the stats cache for a list of pacts in a single pass.
  ///
  /// Intended to be called by [DashboardViewModel.load] after showup generation
  /// so that all subsequent navigations (pact detail, showup detail) are
  /// guaranteed cache hits and incur no additional DB round-trips.
  Future<void> preWarmCache(List<Pact> pacts) async {
    for (final pact in pacts) {
      final showups = await _showupRepository.getShowupsForPact(pact.id);
      _statsCache[pact.id] = buildStats(pact: pact, showups: showups);
    }
  }

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
  /// Priority order:
  /// 1. If [showups] is non-empty, compute fresh stats from the provided list
  ///    (caller already loaded showups — no cache check needed).
  /// 2. If [showups] is empty and a cache entry exists, return the cached value
  ///    (cache hit — no DB round-trip).
  /// 3. If [showups] is empty and no cache entry exists, fall back to the
  ///    persisted [Pact.stats] snapshot (lazy path for stopped/completed pacts
  ///    whose showups have been deleted).
  PactStats currentStats({
    required Pact pact,
    required List<Showup> showups,
  }) {
    if (showups.isNotEmpty) {
      return buildStats(pact: pact, showups: showups);
    }
    // Cache hit — return without a DB round-trip.
    final cached = _statsCache[pact.id];
    if (cached != null) return cached;
    // Lazy fallback: no cache and no showups (e.g. stopped pact).
    return pact.stats ?? buildStats(pact: pact, showups: showups);
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
    // Evict stale cache entry before the write-through so any concurrent read
    // between the eviction and the repopulation falls back to DB rather than
    // returning stale data.
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
    final statsBeforeStop = existingStats ?? currentStats(pact: pact, showups: showups);
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

    // Evict-only: showups are deleted by the transaction, so there is nothing
    // valid to cache.  The next read will use the frozen pact.stats snapshot.
    _statsCache.remove(pactId);

    return updated;
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
