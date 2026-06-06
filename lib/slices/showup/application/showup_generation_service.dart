import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

// Stateless; deduplicates via ShowupRepository.saveShowups (skips existing IDs — idempotent).
class ShowupGenerationService {
  final ShowupRepository _repository;

  const ShowupGenerationService({required ShowupRepository repository}) : _repository = repository;

  /// Skips slots whose window has already closed at [Pact.createdAt] — prevents
  /// re-inserting intra-day slots omitted at pact-creation time (e.g. an 8am slot
  /// on a pact created at 10pm). Slots still open at [Pact.createdAt] are kept
  /// even if [scheduledAt] is slightly before it (HAB-84 edge case).
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
