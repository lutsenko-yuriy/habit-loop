import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Façade for view models — composes [PactRepository], [ShowupRepository], [PactTransactionService].
///
/// Invariant: [pactStatsServiceProvider] must NOT watch [pactServiceProvider] — circular dependency.
class PactService {
  PactService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    required PactStatsService pactStatsService,
    required SyncService syncService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService,
        _pactStatsService = pactStatsService,
        _syncService = syncService;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;

  final PactStatsService _pactStatsService;

  final SyncService _syncService;

  // ---------------------------------------------------------------------------
  // Atomic creation
  // ---------------------------------------------------------------------------

  // Atomic: delegates to PactTransactionService.savePactWithShowups.
  Future<void> createPact(Pact pact, List<Showup> showups) async {
    await _transactionService.savePactWithShowups(pact, showups);
    unawaited(_syncService.uploadPact(pact));
    for (final s in showups) {
      unawaited(_syncService.uploadShowup(s));
    }
  }

  // Only includes showups whose window ends after now (excludes entirely past slots).
  // Returns the built Pact to avoid a second repository round-trip for stat initialization.
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
    ).where((s) => s.scheduledAt.add(pact.showupDuration).isAfter(now)).toList();
    await createPact(pact, showups);
    return pact;
  }

  // ---------------------------------------------------------------------------
  // Delegating reads
  // ---------------------------------------------------------------------------

  Future<Pact?> getPact(String id) => _pactRepository.getPactById(id);

  Future<List<Pact>> getAllPacts() => _pactRepository.getAllPacts();

  Future<List<Pact>> getActivePacts() => _pactRepository.getActivePacts();

  // Exposed so view models don't depend on ShowupRepository directly.
  Future<List<Showup>> getShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);

  // ---------------------------------------------------------------------------
  // Delegating writes
  // ---------------------------------------------------------------------------

  // On completed status, evicts the stale cache entry in PactStatsService.
  Future<void> updatePact(Pact pact) async {
    await _pactRepository.updatePact(pact);
    if (pact.status == PactStatus.completed) {
      _pactStatsService.onPactCompleted(pact.id);
    }
    unawaited(_syncService.uploadPact(pact));
  }

  Future<void> deletePact(String id) => _pactRepository.deletePact(id);
}
