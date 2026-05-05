import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart'
    show pactRepositoryProvider, showupRepositoryProvider;
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Owns pact stats calculation and persistence across pact/showup mutations.
///
/// Keeping this logic in one service prevents UI view models from each
/// maintaining their own version of the `Pact.stats` invariant.
///
/// When [transactionService] is provided, [stopPact] wraps the update-pact and
/// delete-showups writes in a single SQLite transaction (atomic). When omitted
/// (e.g. in tests that inject in-memory repositories), it falls back to the
/// two-step path.
class PactStatsService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService? _transactionService;

  const PactStatsService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    PactTransactionService? transactionService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService;

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

  /// Returns fresh stats whenever showups still exist, falling back to the
  /// persisted snapshot only after the showups were deleted (stopped pact).
  PactStats currentStats({
    required Pact pact,
    required List<Showup> showups,
  }) {
    if (showups.isNotEmpty) {
      return buildStats(pact: pact, showups: showups);
    }
    return pact.stats ?? buildStats(pact: pact, showups: showups);
  }

  Future<Pact> persistStats({
    required Pact pact,
    required List<Showup> showups,
  }) async {
    final updatedPact = pact.copyWith(
      stats: buildStats(pact: pact, showups: showups),
    );
    await _pactRepository.updatePact(updatedPact);
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
    await _syncStatsBestEffort(updatedShowup.pactId);
    return updatedShowup;
  }

  /// Stops the pact atomically.
  ///
  /// When a [PactTransactionService] was supplied at construction, the pact
  /// update and the showup deletion are wrapped in a single SQLite transaction
  /// so either both succeed or both are rolled back. When no transaction service
  /// is present (e.g. in tests that use in-memory repositories) the legacy
  /// two-step path is used with a manual rollback attempt on failure.
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

    if (_transactionService != null) {
      // Atomic path: update pact + delete showups in one SQLite transaction.
      await _transactionService.stopPactTransaction(
        updatedPact: updated,
        pactId: pactId,
      );
    } else {
      // Legacy fallback path for in-memory repositories (used in tests).
      // The two-step path retains a manual rollback so that a failure on the
      // showup-delete step does not leave the pact permanently stopped without
      // its showups being cleaned up.
      await _pactRepository.updatePact(updated);
      try {
        await _showupRepository.deleteShowupsForPact(pactId);
      } catch (error, stackTrace) {
        await _pactRepository.updatePact(pact);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

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

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides [PactStatsService] by composing the lower-level repository and
/// transaction service providers.
///
/// View models use this provider instead of constructing [PactStatsService]
/// inline — this removes their direct dependency on the repository providers.
final pactStatsServiceProvider = Provider<PactStatsService>((ref) {
  return PactStatsService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
  );
});
