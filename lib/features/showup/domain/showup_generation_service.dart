import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

/// Orchestrates lazy showup generation for a given [Pact] and date window.
///
/// The service is stateless — all persistence is delegated to [ShowupRepository].
/// Callers (e.g. [DashboardViewModel]) invoke [ensureShowupsExist] whenever
/// they need showups to be present for a given window. The service deduplicates
/// against already-persisted showups via [ShowupRepository.saveShowups], which
/// silently skips IDs that already exist, making every call idempotent.
class ShowupGenerationService {
  final ShowupRepository _repository;

  /// Creates a [ShowupGenerationService] backed by [repository].
  const ShowupGenerationService({required ShowupRepository repository})
      : _repository = repository;

  /// Ensures that all showups for [pact] within the window [[from], [to]]
  /// are persisted in the repository.
  ///
  /// - Uses [ShowupGenerator.generateWindow] to produce the candidate showups
  ///   for the requested window (automatically clamped to the pact boundaries).
  /// - Delegates to [ShowupRepository.saveShowups], which skips IDs that are
  ///   already stored — so calling this method multiple times with the same or
  ///   overlapping windows is safe and produces no duplicates.
  ///
  /// Returns normally even when all generated showups already existed (i.e.
  /// the net saved count is 0).
  Future<void> ensureShowupsExist(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) async {
    final candidates = ShowupGenerator.generateWindow(pact, from: from, to: to);
    if (candidates.isEmpty) return;
    await _repository.saveShowups(candidates);
  }
}
