import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Owns pact stats calculation, backed by the shared [PactDetailCache]
/// (HAB-174 WU2 — replaces this service's former private `_statsCache`).
///
/// - Lazy hit: [currentStats] with no showups delegates to [PactDetailCache.load];
///   non-empty showups always recompute directly, bypassing the cache.
/// - Write-through: [persistShowupStatus] evicts the stale cache entry before
///   the DB write, then [persistStats] repopulates it.
/// - Evict-only: [stopPact] evicts without re-populating.
/// - [stopPact] wraps pact update + showup delete atomically.
class PactStatsService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;
  final SyncService _syncService;
  final PactDetailCache _cache;

  PactStatsService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    required SyncService syncService,
    required PactDetailCache cache,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService,
        _syncService = syncService,
        _cache = cache;

  /// [breaks] is used only to derive [PactStats.skippedOnBreak] (HAB-195) —
  /// defaults to empty, so a caller that doesn't yet know about breaks (every
  /// call site until WU3 wires the dashboard/showup-detail view models
  /// through) simply computes 0, never a regression versus pre-HAB-195
  /// behaviour.
  PactStats buildStats({
    required Pact pact,
    required List<Showup> showups,
    DateTime? endDate,
    List<PactBreak> breaks = const [],
  }) {
    final effectivePact = endDate == null ? pact : pact.copyWith(endDate: endDate);
    return PactStats.compute(
      startDate: effectivePact.startDate,
      endDate: effectivePact.endDate,
      showups: showups,
      totalShowups: ShowupGenerator.countTotal(effectivePact),
      breaks: breaks,
    );
  }

  // Non-empty showups → computes fresh stats directly (bypasses cache).
  // Empty showups → delegates to PactDetailCache.load (lazy hit/miss + the
  // frozen-snapshot fallback both live there now) — already break-aware
  // (HAB-195 WU2), since PactDetailCache fetches the pact's breaks itself.
  Future<PactStats> currentStats({
    required Pact pact,
    required List<Showup> showups,
    List<PactBreak> breaks = const [],
  }) async {
    if (showups.isNotEmpty) {
      return buildStats(pact: pact, showups: showups, breaks: breaks);
    }
    final bundle = await _cache.load(pact.id);
    return bundle.stats;
  }

  /// [breaks] is `null` by default rather than defaulting to an empty list —
  /// that distinction matters here (HAB-195): when `null`, [_cache.refresh]
  /// is called *without* a breaks argument, so it falls back to its own
  /// correct behaviour of fetching the pact's real breaks from the DB
  /// (HAB-195 WU2). Only the frozen `pact.stats` snapshot written here
  /// conservatively computes 0 for skippedOnBreak in that case — the cache's
  /// bundle (the live read path Pact Detail actually uses) stays correct
  /// either way. Pass an explicit list (even an empty one) once a caller
  /// knows the pact's breaks, and both the snapshot and the cache agree.
  Future<Pact> persistStats({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
    List<PactBreak>? breaks,
  }) async {
    final stats = buildStats(pact: pact, showups: showups, breaks: breaks ?? const []);
    final updatedPact = pact.copyWith(stats: stats);
    await _pactRepository.updatePact(updatedPact);
    // Populate the cache without a redundant DB re-fetch — pact and showups are in hand.
    // now is forwarded from the caller's own clock (e.g. todayProvider/showupDetailNowProvider)
    // rather than left to PactDetailCache's real-wall-clock fallback, which would otherwise
    // mis-bucket the cached timeline's tail zone whenever a test (or a paused/backgrounded
    // session) has the app clock diverge from the real one.
    await _cache.refresh(pact.id, pact: updatedPact, showups: showups, breaks: breaks, now: now);
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

  Future<Pact?> syncStats(String pactId, {DateTime? now}) async {
    final pact = await _pactRepository.getPactById(pactId);
    if (pact == null) return null;

    final showups = await _showupRepository.getShowupsForPact(pactId);
    return persistStats(pact: pact, showups: showups, now: now);
  }

  // Showup status is the source of truth; stats sync failure does not roll back the status update.
  Future<Showup> persistShowupStatus({
    required Showup showup,
    required ShowupStatus status,
    bool? redeemable,
    DateTime? now,
  }) async {
    final updatedShowup = showup.copyWith(status: status, redeemable: redeemable);
    await _showupRepository.updateShowup(updatedShowup);
    unawaited(_syncService.uploadShowup(updatedShowup));
    // Evict before repopulation — racing reads fall back to DB, not stale data.
    _cache.evict(updatedShowup.pactId);
    await _syncStatsBestEffort(updatedShowup.pactId, now: now);
    return updatedShowup;
  }

  // Atomic: pact update + future-showup deletion via transactionService.
  // Past showups are kept (HAB-208) — see PactTransactionService.stopPactTransaction.
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
      now: now,
    );

    unawaited(_syncService.uploadPact(updated));

    // Evict-only: the transaction only removed future showups (HAB-208), but
    // this call site doesn't have the pruned list in hand — the next load()
    // miss re-fetches the pact's real remaining showups from the DB and
    // recomputes fresh, correct stats from them.
    _cache.evict(pactId);

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

  Future<void> _syncStatsBestEffort(String pactId, {DateTime? now}) async {
    try {
      await syncStats(pactId, now: now);
    } catch (_) {
      // The showup status is the source of truth for the user action. If the
      // derived pact stats snapshot fails to persist, keep the primary update
      // successful and let pact detail recompute fresh stats from showups.
    }
  }
}
