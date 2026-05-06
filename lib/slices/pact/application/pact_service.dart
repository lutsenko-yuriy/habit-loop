import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
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
///
/// [updatePact] checks whether the pact being persisted has
/// [PactStatus.completed] and, if so, notifies [_pactStatsService] via
/// [PactStatsService.onPactCompleted] so the stale cache entry is evicted.
/// This keeps the view model completely unaware of cache management.
///
/// Note on provider ordering: [pactServiceProvider] watches [pactStatsServiceProvider]
/// (one-way dependency). [pactStatsServiceProvider] must never watch [pactServiceProvider]
/// — doing so would create a circular dependency in the Riverpod graph.
class PactService {
  PactService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    required PactStatsService pactStatsService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService,
        _pactStatsService = pactStatsService;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;

  /// Reference to [PactStatsService] used exclusively to notify the cache when
  /// [updatePact] persists a completed pact.
  final PactStatsService _pactStatsService;

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

  /// Updates [pact] in the repository.
  ///
  /// If [pact.status] is [PactStatus.completed], notifies [_pactStatsService]
  /// via [PactStatsService.onPactCompleted] so the stale cache entry is evicted
  /// atomically with the repository write.  Throws if the pact does not exist.
  Future<void> updatePact(Pact pact) async {
    await _pactRepository.updatePact(pact);
    if (pact.status == PactStatus.completed) {
      _pactStatsService.onPactCompleted(pact.id);
    }
  }

  /// Deletes the pact with [id]. No-op if the pact does not exist.
  Future<void> deletePact(String id) => _pactRepository.deletePact(id);
}
