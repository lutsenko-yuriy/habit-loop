import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';

/// Production implementation of [SyncService].
///
/// Governs all Firestore writes via [SyncCircuitBreaker]: checks [canRequest]
/// before every upload and calls [recordSuccess] / [recordFailure] depending on
/// the outcome. Automatically triggers [flushDirtyRecords] whenever a
/// successful upload transitions the CB from half-open to closed.
class FirestoreSyncService implements SyncService {
  static const int _flushCap = 400;

  final FirestoreClient _firestoreClient;
  final AuthService _authService;
  final SyncCircuitBreaker _circuitBreaker;
  final PactSyncRepository _pactSyncRepository;
  final ShowupSyncRepository _showupSyncRepository;

  FirestoreSyncService({
    required FirestoreClient firestoreClient,
    required AuthService authService,
    required SyncCircuitBreaker circuitBreaker,
    required PactSyncRepository pactSyncRepository,
    required ShowupSyncRepository showupSyncRepository,
  })  : _firestoreClient = firestoreClient,
        _authService = authService,
        _circuitBreaker = circuitBreaker,
        _pactSyncRepository = pactSyncRepository,
        _showupSyncRepository = showupSyncRepository;

  @override
  Future<void> uploadPact(Pact pact) async {
    await _uploadWithCb(
      upload: () async {
        final userId = _authService.currentUserId;
        if (userId == null) return;
        await _firestoreClient.upsertPact(userId, pact.id, SyncMapper.pactToDocument(pact));
      },
      onSynced: () async {
        await _pactSyncRepository.markPactSynced(pact.id, DateTime.now());
      },
    );
  }

  @override
  Future<void> uploadShowup(Showup showup) async {
    await _uploadWithCb(
      upload: () async {
        final userId = _authService.currentUserId;
        if (userId == null) return;
        await _firestoreClient.upsertShowup(userId, showup.id, SyncMapper.showupToDocument(showup));
      },
      onSynced: () async {
        await _showupSyncRepository.markShowupSynced(showup.id, DateTime.now());
      },
    );
  }

  @override
  Future<void> flushDirtyRecords() async {
    if (!_circuitBreaker.canRequest) return;

    final dirtyPacts = await _pactSyncRepository.getDirtyPacts();
    final dirtyShowups = await _showupSyncRepository.getDirtyShowups();

    final items = <Future<void> Function()>[];
    for (final pact in dirtyPacts) {
      items.add(() => uploadPact(pact));
    }
    for (final showup in dirtyShowups) {
      items.add(() => uploadShowup(showup));
    }

    final capped = items.take(_flushCap);
    for (final upload in capped) {
      if (!_circuitBreaker.canRequest) break;
      await upload();
    }
  }

  @override
  void triggerManualSync() {
    _circuitBreaker.triggerManualSync();
    unawaited(flushDirtyRecords());
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Executes [upload] if the CB allows requests, then calls [onSynced] and
  /// [recordSuccess] on success, or [recordFailure] on any error.
  ///
  /// If the CB was in [SyncCircuitBreakerState.halfOpen] before this call and
  /// transitions to [SyncCircuitBreakerState.closed] via [recordSuccess], a
  /// [flushDirtyRecords] pass is automatically fired to pick up all records
  /// that accumulated while the CB was non-closed.
  Future<void> _uploadWithCb({
    required Future<void> Function() upload,
    required Future<void> Function() onSynced,
  }) async {
    if (!_circuitBreaker.canRequest) return;
    final wasHalfOpen = _circuitBreaker.currentState == SyncCircuitBreakerState.halfOpen;
    try {
      await upload();
      await onSynced();
      _circuitBreaker.recordSuccess();
      if (wasHalfOpen) unawaited(flushDirtyRecords());
    } catch (_) {
      _circuitBreaker.recordFailure();
    }
  }
}
