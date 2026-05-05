import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/persistence/repository_providers.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Application service that composes [PactRepository], [ShowupRepository], and
/// [PactTransactionService] into a single façade for view models.
///
/// View models depend only on [PactService] (and [PactStatsService] for stat
/// computations) — they no longer import persistence-layer providers directly.
///
/// [createPact] delegates to [PactTransactionService.savePactWithShowups] which
/// is always atomic: on SQLite it uses a single `db.transaction()` call so
/// either everything commits or nothing does; the in-memory test double applies
/// a best-effort manual rollback.
class PactService {
  const PactService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;

  // ---------------------------------------------------------------------------
  // Atomic creation
  // ---------------------------------------------------------------------------

  /// Atomically creates [pact] and all [showups] via [PactTransactionService].
  ///
  /// Delegates to [PactTransactionService.savePactWithShowups] so either both
  /// the pact insert and all showup inserts commit together, or nothing does.
  Future<void> createPact(Pact pact, List<Showup> showups) async {
    await _transactionService.savePactWithShowups(pact, showups);
  }

  /// Builds a pact from [builder], generates the initial showup window, and
  /// atomically persists both via [createPact].
  ///
  /// Only showups whose [Showup.scheduledAt] is on or after [now] are included
  /// (showups already in the past are excluded at creation time so a user who
  /// creates a pact at 10 pm never sees an already-failed 8 am slot on day 1).
  ///
  /// Returns the built [Pact] so the caller can proceed with stat
  /// initialization without a second repository round-trip.
  Future<Pact> createPactFromBuilder({
    required PactBuilder builder,
    required String id,
    required DateTime now,
    required DateTime windowEnd,
  }) async {
    final pact = builder.build(id: id, createdAt: now);
    final showups = ShowupGenerator.generateWindow(
      pact,
      from: pact.startDate,
      to: windowEnd,
    ).where((s) => !s.scheduledAt.isBefore(now)).toList();
    await createPact(pact, showups);
    return pact;
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

  /// Returns showups for the given pact from the showup repository.
  ///
  /// Exposed so that view models can fetch showups without depending on the
  /// [ShowupRepository] directly.
  Future<List<Showup>> getShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);

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
