import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/sync/force_sync_result.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';

/// Governs all Firestore writes through [SyncCircuitBreaker].
/// [pullRemoteChanges] uses last-writer-wins on `updated_at` / `synced_at`.
class FirestoreSyncService implements SyncService {
  static const int _flushCap = 400;

  final FirestoreClient _firestoreClient;
  final AuthService _authService;
  final SyncCircuitBreaker _circuitBreaker;
  final PactSyncRepository _pactSyncRepository;
  final ShowupSyncRepository _showupSyncRepository;
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final RemoteConfigService? _remoteConfig;

  bool get _syncEnabled => _remoteConfig?.getBool('network_sync_enabled') ?? true;

  FirestoreSyncService({
    required FirestoreClient firestoreClient,
    required AuthService authService,
    required SyncCircuitBreaker circuitBreaker,
    required PactSyncRepository pactSyncRepository,
    required ShowupSyncRepository showupSyncRepository,
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    RemoteConfigService? remoteConfig,
  })  : _firestoreClient = firestoreClient,
        _authService = authService,
        _circuitBreaker = circuitBreaker,
        _pactSyncRepository = pactSyncRepository,
        _showupSyncRepository = showupSyncRepository,
        _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _remoteConfig = remoteConfig;

  @override
  Future<void> uploadPact(Pact pact) async {
    if (!_syncEnabled) return;
    final userId = _authService.currentUserId;
    if (userId == null || _authService.isAnonymous) return;
    await _uploadWithCb(
      upload: () async {
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
    if (!_syncEnabled) return;
    final userId = _authService.currentUserId;
    if (userId == null || _authService.isAnonymous) return;
    await _uploadWithCb(
      upload: () async {
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
    if (!_syncEnabled) return;
    if (!_circuitBreaker.canRequest) return;
    if (_authService.isAnonymous) return;

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
    if (!_syncEnabled) return;
    if (_authService.isAnonymous) return;
    _circuitBreaker.triggerManualSync();
    unawaited(flushDirtyRecords());
  }

  @override
  Future<ForceSyncResult> forceSyncAll() async {
    if (!_syncEnabled) return const ForceSyncResult(attempted: 0, pactsFailed: 0, showupsFailed: 0);
    if (_authService.isAnonymous) return const ForceSyncResult(attempted: 0, pactsFailed: 0, showupsFailed: 0);
    try {
      await _pactSyncRepository.markAllPactsDirty();
      await _showupSyncRepository.markAllShowupsDirty();
      final allDirtyPacts = await _pactSyncRepository.getDirtyPacts();
      final allDirtyShowups = await _showupSyncRepository.getDirtyShowups();
      final attempted = allDirtyPacts.length + allDirtyShowups.length;
      await flushDirtyRecords();
      // Successfully uploaded records are marked synced (dirty=0) and no longer
      // returned here — what remains are upload failures.
      final remainingPacts = await _pactSyncRepository.getDirtyPacts();
      final remainingShowups = await _showupSyncRepository.getDirtyShowups();
      return ForceSyncResult(
        attempted: attempted,
        pactsFailed: remainingPacts.length,
        showupsFailed: remainingShowups.length,
      );
    } catch (_) {
      return const ForceSyncResult(attempted: 0, pactsFailed: 0, showupsFailed: 0);
    }
  }

  @override
  Future<void> pullRemoteChanges() async {
    if (!_syncEnabled) return;
    if (_circuitBreaker.currentState != SyncCircuitBreakerState.closed) return;

    final userId = _authService.currentUserId;
    if (userId == null || _authService.isAnonymous) return;

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

  // Merge rules: absent → insert; dirty → keep local; remote newer → overwrite;
  // else → keep local. [existsGuard], if given, re-checks existence right
  // before the update to guard a TOCTOU window (used only by the showup path,
  // where stopPactTransaction can delete a showup between the initial check
  // and now).
  Future<void> _mergeRemoteRecord<T>({
    required Map<String, dynamic> doc,
    required DateTime now,
    required Future<T?> Function(String id) getLocal,
    required Future<DateTime?> Function(String id) getSyncedAt,
    required T Function(Map<String, dynamic>) fromDocument,
    required Future<void> Function(T) insert,
    required Future<void> Function(T) update,
    required Future<void> Function(String id, DateTime now) markSynced,
    Future<bool> Function(String id)? existsGuard,
  }) async {
    final String id = doc['id'] as String;
    final local = await getLocal(id);

    if (local == null) {
      final record = fromDocument(doc);
      await insert(record);
      await markSynced(id, now);
      return;
    }

    final localSyncedAt = await getSyncedAt(id);
    if (localSyncedAt == null) return; // dirty → keep local

    final remoteUpdatedAt = SyncMapper.updatedAtFromDocument(doc);
    if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localSyncedAt)) return; // not newer

    if (existsGuard != null && !(await existsGuard(id))) return;

    final remote = fromDocument(doc);
    await update(remote);
    await markSynced(id, now);
  }

  Future<void> _mergeRemotePact(Map<String, dynamic> doc, DateTime now) => _mergeRemoteRecord<Pact>(
        doc: doc,
        now: now,
        getLocal: _pactRepository.getPactById,
        getSyncedAt: _pactSyncRepository.getPactSyncedAt,
        fromDocument: SyncMapper.pactFromDocument,
        insert: _pactRepository.savePact,
        update: _pactRepository.updatePact,
        markSynced: _pactSyncRepository.markPactSynced,
      );

  Future<void> _mergeRemoteShowup(Map<String, dynamic> doc, DateTime now) => _mergeRemoteRecord<Showup>(
        doc: doc,
        now: now,
        getLocal: _showupRepository.getShowupById,
        getSyncedAt: _showupSyncRepository.getShowupSyncedAt,
        fromDocument: SyncMapper.showupFromDocument,
        insert: _showupRepository.saveShowup,
        update: _showupRepository.updateShowup,
        markSynced: _showupSyncRepository.markShowupSynced,
        existsGuard: (id) async => await _showupRepository.getShowupById(id) != null,
      );

  // If CB transitions halfOpen → closed on success, fires flushDirtyRecords
  // to pick up records that accumulated while the CB was non-closed.
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
