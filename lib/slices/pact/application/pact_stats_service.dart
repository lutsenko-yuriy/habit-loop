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

/// Owns pact stats calculation and the in-memory stats cache.
///
/// Cache (keyed by pactId, session-scoped):
/// - Lazy hit: [currentStats] with no showups returns cached value; non-empty showups always recompute.
/// - Write-through: [persistShowupStatus] evicts stale entry, then repopulates.
/// - Evict-only: [stopPact] and [onPactCompleted] evict without re-populating.
/// - [stopPact] wraps pact update + showup delete atomically.
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

  // Non-empty showups → computes fresh stats directly (bypasses cache).
  // Empty showups → lazy cache path: hit returns immediately; miss loads from DB.
  Future<PactStats> currentStats({
    required Pact pact,
    required List<Showup> showups,
  }) async {
    if (showups.isNotEmpty) {
      return buildStats(pact: pact, showups: showups);
    }
    final cached = _statsCache[pact.id];
    if (cached != null) return cached;

    // Cache miss: load from DB. Stopped/completed pacts with deleted showups fall back
    // to the frozen Pact.stats snapshot when the query returns empty.
    final loadedShowups = await _showupRepository.getShowupsForPact(pact.id);
    if (loadedShowups.isEmpty && pact.stats != null) {
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

  // Showup status is the source of truth; stats sync failure does not roll back the status update.
  Future<Showup> persistShowupStatus({
    required Showup showup,
    required ShowupStatus status,
    bool? redeemable,
  }) async {
    final updatedShowup = showup.copyWith(status: status, redeemable: redeemable);
    await _showupRepository.updateShowup(updatedShowup);
    unawaited(_syncService.uploadShowup(updatedShowup));
    // Evict before repopulation — racing reads fall back to DB, not stale data.
    _statsCache.remove(updatedShowup.pactId);
    await _syncStatsBestEffort(updatedShowup.pactId);
    return updatedShowup;
  }

  // Atomic: pact update + showup deletion via transactionService.
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
      stoppedAt: stoppedDate,
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

  // Cache eviction only — repository write is done by the caller (PactService.updatePact).
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
