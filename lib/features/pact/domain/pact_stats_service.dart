import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

/// Owns pact stats calculation and persistence across pact/showup mutations.
///
/// Keeping this logic in one service prevents UI view models from each
/// maintaining their own version of the `Pact.stats` invariant.
class PactStatsService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  const PactStatsService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  PactStats buildStats({
    required Pact pact,
    required List<Showup> showups,
    DateTime? endDate,
  }) {
    final effectivePact =
        endDate == null ? pact : pact.copyWith(endDate: endDate);
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

  Future<Pact> stopPact({
    required Pact pact,
    required String pactId,
    required DateTime now,
    String? reason,
    PactStats? existingStats,
  }) async {
    final showups = await _showupRepository.getShowupsForPact(pactId);
    final stoppedDate = DateTime(now.year, now.month, now.day);
    final statsBeforeStop =
        existingStats ?? currentStats(pact: pact, showups: showups);
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

    await _pactRepository.updatePact(updated);
    try {
      await _showupRepository.deleteShowupsForPact(pactId);
    } catch (error, stackTrace) {
      await _pactRepository.updatePact(pact);
      Error.throwWithStackTrace(error, stackTrace);
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
