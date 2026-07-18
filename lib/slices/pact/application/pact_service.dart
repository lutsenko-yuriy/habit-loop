import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Façade for view models — composes [PactRepository], [ShowupRepository], [PactTransactionService].
///
/// [PactDetailCache] sits at the same leaf level [PactStatsService] depends on
/// (repositories + grouper only) — no circularity (HAB-174 WU2).
class PactService {
  PactService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    required PactDetailCache cache,
    required SyncService syncService,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _transactionService = transactionService,
        _cache = cache,
        _syncService = syncService;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactTransactionService _transactionService;

  final PactDetailCache _cache;

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

  // Write-through to the shared cache for every status, not just completed —
  // a plain note/habitName/reminder edit must also be reflected immediately
  // (HAB-174 WU0 finding: the completed-only branch this replaced left note
  // edits silently stale). reuseCachedShowups is safe here: updatePact never
  // changes a pact's showups, only pact-level fields.
  Future<void> updatePact(Pact pact, {DateTime? now}) async {
    await _pactRepository.updatePact(pact);
    // now is forwarded from the caller's own clock rather than left to
    // PactDetailCache's real-wall-clock fallback — see persistStats's comment
    // in pact_stats_service.dart for why this matters for the cached timeline.
    await _cache.refresh(pact.id, pact: pact, reuseCachedShowups: true, now: now);
    unawaited(_syncService.uploadPact(pact));
  }

  Future<void> deletePact(String id) => _pactRepository.deletePact(id);

  Future<void> archivePact(String pactId, bool archived) async {
    await _pactRepository.archivePact(pactId, archived);
    final updated = await _pactRepository.getPactById(pactId);
    if (updated != null) unawaited(_syncService.uploadPact(updated));
  }
}
