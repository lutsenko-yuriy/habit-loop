import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart'
    show pactRepositoryProvider, showupRepositoryProvider;
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Application service that composes [PactRepository], [ShowupRepository], and
/// [PactTransactionService] into a single façade for view models.
///
/// View models depend only on [PactService] (and [PactStatsService] for stat
/// computations) — they no longer import persistence-layer providers directly.
///
/// When [transactionService] is non-null (SQLite production path), [createPact]
/// is atomic: the pact insert and all showup inserts are wrapped in a single
/// `db.transaction()` call so either everything commits or nothing does.
///
/// When [transactionService] is null (in-memory fallback used in tests),
/// [createPact] uses the two-step save + manual rollback path that was
/// previously inlined in `PactCreationViewModel.submit()`.
class PactService {
  const PactService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService? transactionService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService? _transactionService;

  // ---------------------------------------------------------------------------
  // Atomic creation
  // ---------------------------------------------------------------------------

  /// Atomically creates [pact] and all [showups].
  ///
  /// When [transactionService] is non-null, the two inserts are wrapped in a
  /// single SQLite transaction — sqflite rolls back automatically on any
  /// exception, so neither orphaned pacts nor orphaned showups can be left in
  /// the database.
  ///
  /// When [transactionService] is null (in-memory repositories, used in tests),
  /// falls back to the sequential save + manual rollback path.
  Future<void> createPact(Pact pact, List<Showup> showups) async {
    if (_transactionService != null) {
      // Atomic SQLite path.
      await _transactionService.savePactWithShowups(pact, showups);
    } else {
      // Fallback path for in-memory repositories (used in tests).
      await _pactRepository.savePact(pact);
      try {
        for (final showup in showups) {
          await _showupRepository.saveShowup(showup);
        }
      } catch (error, stackTrace) {
        // Roll back the pact so the app is not left with an orphaned pact.
        try {
          await _pactRepository.deletePact(pact.id);
        } catch (_) {
          // Ignore rollback errors — the original error is more informative.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delegating reads
  // ---------------------------------------------------------------------------

  /// Returns the pact with [id], or `null` if it does not exist.
  Future<Pact?> getPact(String id) => _pactRepository.getPactById(id);

  /// Returns all pacts (active, stopped, and completed).
  Future<List<Pact>> getAllPacts() => _pactRepository.getAllPacts();

  /// Returns only active pacts.
  Future<List<Pact>> getActivePacts() => _pactRepository.getActivePacts();

  // ---------------------------------------------------------------------------
  // Delegating writes
  // ---------------------------------------------------------------------------

  /// Updates [pact] in the repository. Throws if the pact does not exist.
  Future<void> updatePact(Pact pact) => _pactRepository.updatePact(pact);

  /// Deletes the pact with [id]. No-op if the pact does not exist.
  Future<void> deletePact(String id) => _pactRepository.deletePact(id);
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides [PactService] by composing the three lower-level providers.
///
/// Works regardless of whether the lower-level providers are backed by
/// in-memory (test) or SQLite (production) implementations.
final pactServiceProvider = Provider<PactService>((ref) {
  return PactService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
  );
});
