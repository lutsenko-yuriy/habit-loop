import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

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
  const ShowupGenerationService({required ShowupRepository repository}) : _repository = repository;

  /// Ensures that all showups for [pact] within the window [[from], [to]]
  /// are persisted in the repository.
  ///
  /// - Uses [ShowupGenerator.generateWindow] to produce the candidate showups
  ///   for the requested window (automatically clamped to the pact boundaries).
  /// - Skips any candidate whose showup window ([Showup.scheduledAt] +
  ///   [Pact.showupDuration]) has already closed at [Pact.createdAt] (or
  ///   [Pact.startDate] if [createdAt] is null). This prevents a dashboard
  ///   reload from re-inserting intra-day slots that were intentionally omitted
  ///   at pact-creation time — e.g. an 8am slot on a pact created at 10pm the
  ///   same day.  Slots whose window is still open at [Pact.createdAt] are
  ///   kept even if [scheduledAt] is slightly before [Pact.createdAt] (e.g. a
  ///   09:00–09:30 slot on a pact created at 09:05 — HAB-84).
  /// - Delegates to [ShowupRepository.saveShowups], which skips IDs that are
  ///   already stored — so calling this method multiple times with the same or
  ///   overlapping windows is safe and produces no duplicates.
  ///
  /// Returns the list of showups that were newly saved (i.e. not previously
  /// stored). Returns an empty list when all generated showups already existed.
  Future<List<Showup>> ensureShowupsExist(
    Pact pact, {
    required DateTime from,
    required DateTime to,
  }) async {
    final effectiveCreatedAt = pact.createdAt ?? pact.startDate;
    final candidates = ShowupGenerator.generateWindow(pact, from: from, to: to)
        .where((s) => s.scheduledAt.add(pact.showupDuration).isAfter(effectiveCreatedAt))
        .toList();
    if (candidates.isEmpty) return const [];
    final result = await _repository.saveShowups(candidates);
    if (result.savedCount == 0) return const [];
    // Return only the newly saved showups (candidates not in skippedIds).
    final skipped = result.skippedIds.toSet();
    return candidates.where((s) => !skipped.contains(s.id)).toList();
  }
}
