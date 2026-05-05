import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// In-memory implementation of [PactTransactionService] used in tests.
///
/// Delegates to the injected [PactRepository] and [ShowupRepository]. Because
/// in-memory repositories cannot roll back partial mutations at the storage
/// level, [savePactWithShowups] applies a best-effort manual rollback on
/// showup-write failure so the pact does not remain orphaned in test scenarios.
class InMemoryPactTransactionService implements PactTransactionService {
  const InMemoryPactTransactionService(this._pactRepository, this._showupRepository);

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  @override
  Future<void> savePactWithShowups(Pact pact, List<Showup> showups) async {
    await _pactRepository.savePact(pact);
    try {
      final result = await _showupRepository.saveShowups(showups);
      if (!result.allSaved) {
        throw StateError('Some showups could not be saved (duplicate IDs)');
      }
    } catch (error, stackTrace) {
      // Roll back the pact so the in-memory store is not left with an orphan.
      try {
        await _pactRepository.deletePact(pact.id);
      } catch (_) {
        // Ignore rollback errors — the original error is more informative.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
  }) async {
    await _showupRepository.deleteShowupsForPact(pactId);
    final stopped = updatedPact.copyWith(status: PactStatus.stopped);
    await _pactRepository.updatePact(stopped);
  }
}
