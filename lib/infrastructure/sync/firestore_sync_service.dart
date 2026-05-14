import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
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
///
/// Pull-on-start ([pullRemoteChanges]) only runs when the CB is fully
/// [SyncCircuitBreakerState.closed] and uses a last-writer-wins merge strategy
/// based on the `updated_at` / `synced_at` timestamps.
class FirestoreSyncService implements SyncService {
  static const int _flushCap = 400;

  final FirestoreClient _firestoreClient;
  final AuthService _authService;
  final SyncCircuitBreaker _circuitBreaker;
  final PactSyncRepository _pactSyncRepository;
  final ShowupSyncRepository _showupSyncRepository;
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  FirestoreSyncService({
    required FirestoreClient firestoreClient,
    required AuthService authService,
    required SyncCircuitBreaker circuitBreaker,
    required PactSyncRepository pactSyncRepository,
    required ShowupSyncRepository showupSyncRepository,
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _firestoreClient = firestoreClient,
        _authService = authService,
        _circuitBreaker = circuitBreaker,
        _pactSyncRepository = pactSyncRepository,
        _showupSyncRepository = showupSyncRepository,
        _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  @override
  Future<void> uploadPact(Pact pact) async {
    await _uploadWithCb(
      upload: () async {
        final userId = _authService.currentUserId;
        if (userId == null) return;
        final now = DateTime.now();
        await _firestoreClient.upsertPact(userId, pact.id, SyncMapper.pactToDocument(pact, updatedAt: now));
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
        final now = DateTime.now();
        await _firestoreClient.upsertShowup(userId, showup.id, SyncMapper.showupToDocument(showup, updatedAt: now));
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

  @override
  Future<void> pullRemoteChanges() async {
    if (_circuitBreaker.currentState != SyncCircuitBreakerState.closed) return;

    final userId = _authService.currentUserId;
    if (userId == null) return;

    final now = DateTime.now();

    try {
      final remotePactDocs = await _firestoreClient.getPacts(userId);
      for (final doc in remotePactDocs) {
        try {
          await _mergeRemotePact(doc, now);
        } catch (_) {
          // Isolate per-record errors so one bad document never blocks the rest.
        }
      }

      if (_circuitBreaker.currentState != SyncCircuitBreakerState.closed) return;

      final remoteShowupDocs = await _firestoreClient.getShowups(userId);
      for (final doc in remoteShowupDocs) {
        try {
          await _mergeRemoteShowup(doc, now);
        } catch (_) {
          // Isolate per-record errors.
        }
      }
    } catch (_) {
      _circuitBreaker.recordFailure();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Merges a single remote pact document into the local database.
  ///
  /// Merge rules:
  /// - Not in local DB → insert, mark synced.
  /// - Local is dirty → keep local, skip.
  /// - Remote `updated_at` > local `synced_at` → overwrite, mark synced.
  /// - Otherwise → keep local.
  Future<void> _mergeRemotePact(Map<String, dynamic> doc, DateTime now) async {
    final String id = doc['id'] as String;
    final localPact = await _pactRepository.getPactById(id);

    if (localPact == null) {
      final pact = SyncMapper.pactFromDocument(doc);
      await _pactRepository.savePact(pact);
      await _pactSyncRepository.markPactSynced(id, now);
      return;
    }

    final localSyncedAt = await _pactSyncRepository.getPactSyncedAt(id);
    if (localSyncedAt == null) return; // dirty → keep local

    final remoteUpdatedAt = SyncMapper.updatedAtFromDocument(doc);
    if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localSyncedAt)) return; // not newer

    final remotePact = SyncMapper.pactFromDocument(doc);
    await _pactRepository.updatePact(remotePact);
    await _pactSyncRepository.markPactSynced(id, now);
  }

  /// Merges a single remote showup document into the local database.
  ///
  /// Same merge rules as [_mergeRemotePact].
  Future<void> _mergeRemoteShowup(Map<String, dynamic> doc, DateTime now) async {
    final String id = doc['id'] as String;
    final localShowup = await _showupRepository.getShowupById(id);

    if (localShowup == null) {
      final showup = SyncMapper.showupFromDocument(doc);
      await _showupRepository.saveShowup(showup);
      await _showupSyncRepository.markShowupSynced(id, now);
      return;
    }

    final localSyncedAt = await _showupSyncRepository.getShowupSyncedAt(id);
    if (localSyncedAt == null) return; // dirty → keep local

    final remoteUpdatedAt = SyncMapper.updatedAtFromDocument(doc);
    if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localSyncedAt)) return; // not newer

    final remoteShowup = SyncMapper.showupFromDocument(doc);
    await _showupRepository.updateShowup(remoteShowup);
    await _showupSyncRepository.markShowupSynced(id, now);
  }

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
