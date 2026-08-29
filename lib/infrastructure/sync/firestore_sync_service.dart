import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_break_sync_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/domain/user/user_profile_repository.dart';
import 'package:habit_loop/domain/user/user_profile_sync_repository.dart';
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
  final PactBreakSyncRepository _pactBreakSyncRepository;
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactBreakRepository _pactBreakRepository;
  final UserProfileSyncRepository _userProfileSyncRepository;
  final UserProfileRepository _userProfileRepository;
  final RemoteConfigService? _remoteConfig;
  final _pullCompletedController = StreamController<void>.broadcast();

  bool get _syncEnabled => _remoteConfig?.getBool('network_sync_enabled') ?? true;

  @override
  Stream<void> get pullCompleted => _pullCompletedController.stream;

  FirestoreSyncService({
    required FirestoreClient firestoreClient,
    required AuthService authService,
    required SyncCircuitBreaker circuitBreaker,
    required PactSyncRepository pactSyncRepository,
    required ShowupSyncRepository showupSyncRepository,
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactBreakSyncRepository pactBreakSyncRepository,
    required PactBreakRepository pactBreakRepository,
    required UserProfileSyncRepository userProfileSyncRepository,
    required UserProfileRepository userProfileRepository,
    RemoteConfigService? remoteConfig,
  })  : _firestoreClient = firestoreClient,
        _authService = authService,
        _circuitBreaker = circuitBreaker,
        _pactSyncRepository = pactSyncRepository,
        _showupSyncRepository = showupSyncRepository,
        _pactBreakSyncRepository = pactBreakSyncRepository,
        _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _pactBreakRepository = pactBreakRepository,
        _userProfileSyncRepository = userProfileSyncRepository,
        _userProfileRepository = userProfileRepository,
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
  Future<void> uploadPactBreak(PactBreak pactBreak) async {
    if (!_syncEnabled) return;
    final userId = _authService.currentUserId;
    if (userId == null || _authService.isAnonymous) return;
    await _uploadWithCb(
      upload: () async {
        final now = DateTime.now();
        await _firestoreClient.upsertPactBreak(
            userId, pactBreak.id, SyncMapper.pactBreakToDocument(pactBreak, updatedAt: now));
      },
      onSynced: () async {
        await _pactBreakSyncRepository.markPactBreakSynced(pactBreak.id, DateTime.now());
      },
    );
  }

  @override
  Future<void> uploadUserProfile(UserProfile profile) async {
    if (!_syncEnabled) return;
    final userId = _authService.currentUserId;
    if (userId == null || _authService.isAnonymous) return;
    await _uploadWithCb(
      upload: () async {
        final now = DateTime.now();
        await _firestoreClient.upsertUserProfile(userId, SyncMapper.userProfileToDocument(profile, updatedAt: now));
      },
      onSynced: () async {
        await _userProfileSyncRepository.markUserProfileSynced(DateTime.now());
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
    final dirtyPactBreaks = await _pactBreakSyncRepository.getDirtyPactBreaks();
    final dirtyProfile = await _userProfileSyncRepository.getDirtyUserProfile();

    // Profile first: it's a single record, so putting it ahead of the
    // (potentially large) pact/showup/pact-break backlogs keeps it from
    // being dropped by the _flushCap cut below on a big flush.
    final items = <Future<void> Function()>[];
    if (dirtyProfile != null) {
      items.add(() => uploadUserProfile(dirtyProfile));
    }
    for (final pact in dirtyPacts) {
      items.add(() => uploadPact(pact));
    }
    for (final showup in dirtyShowups) {
      items.add(() => uploadShowup(showup));
    }
    for (final pactBreak in dirtyPactBreaks) {
      items.add(() => uploadPactBreak(pactBreak));
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
      await _pactBreakSyncRepository.markAllPactBreaksDirty();
      await _userProfileSyncRepository.markUserProfileDirty();
      final allDirtyPacts = await _pactSyncRepository.getDirtyPacts();
      final allDirtyShowups = await _showupSyncRepository.getDirtyShowups();
      final allDirtyPactBreaks = await _pactBreakSyncRepository.getDirtyPactBreaks();
      final dirtyProfile = await _userProfileSyncRepository.getDirtyUserProfile();
      final attempted =
          allDirtyPacts.length + allDirtyShowups.length + allDirtyPactBreaks.length + (dirtyProfile != null ? 1 : 0);
      await flushDirtyRecords();
      // Successfully uploaded records are marked synced (dirty=0) and no longer
      // returned here — what remains are upload failures.
      final remainingPacts = await _pactSyncRepository.getDirtyPacts();
      final remainingShowups = await _showupSyncRepository.getDirtyShowups();
      final remainingPactBreaks = await _pactBreakSyncRepository.getDirtyPactBreaks();
      final remainingProfile = await _userProfileSyncRepository.getDirtyUserProfile();
      return ForceSyncResult(
        attempted: attempted,
        pactsFailed: remainingPacts.length,
        showupsFailed: remainingShowups.length,
        pactBreaksFailed: remainingPactBreaks.length,
        userProfileFailed: remainingProfile != null ? 1 : 0,
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

      if (_circuitBreaker.currentState != SyncCircuitBreakerState.closed) return;

      final remotePactBreakDocs = await _firestoreClient.getPactBreaks(userId);
      for (final doc in remotePactBreakDocs) {
        try {
          await _mergeRemotePactBreak(doc, now);
        } catch (_) {
          // Isolate per-record errors.
        }
      }

      if (_circuitBreaker.currentState != SyncCircuitBreakerState.closed) return;

      // Wrapped in its own try/catch (like every entity above) so a malformed
      // profile document can never abort the pact/showup/pact-break pull.
      try {
        final remoteProfileDoc = await _firestoreClient.getUserProfile(userId);
        if (remoteProfileDoc != null) {
          await _mergeRemoteUserProfile(remoteProfileDoc, now);
        }
      } catch (_) {
        // Isolate per-record errors.
      }

      _pullCompletedController.add(null);
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
        insert: (pact) async => _pactRepository.savePact(await _resolvePredecessorConflict(pact)),
        update: _pactRepository.updatePact,
        markSynced: _pactSyncRepository.markPactSynced,
      );

  /// Resolves a HAB-202 chain conflict before inserting a newly-pulled remote
  /// pact: two offline devices may each independently create a successor for
  /// the same predecessor. `savePact`'s "at most one successor" guard would
  /// otherwise throw here, and the per-record try/catch in [pullRemoteChanges]
  /// would silently swallow it — permanently hiding the losing record, even
  /// though it still exists in Firestore and on its origin device.
  ///
  /// Last-write-wins on `createdAt` (falling back to `startDate` for
  /// pre-HAB-116 pacts with no `createdAt`, matching [Pact.createdAt]'s own
  /// documented convention): whichever successor was created later keeps its
  /// link; the other has [Pact.predecessorPactId] cleared via
  /// `clearPredecessorPactId` — the record itself is never dropped, it just
  /// surfaces as unlinked.
  ///
  /// On an exact `createdAt` tie, breaks on `id` (lexicographically greater
  /// wins) rather than always favouring the incoming record. A tie-break that
  /// always resolves the same way regardless of which side is "existing" vs
  /// "incoming" is required for convergence: `isAfter` alone always takes the
  /// incoming-wins branch on a tie, so both devices would independently clear
  /// their own *local* successor's link — surfacing zero links instead of one
  /// (HAB-202 audit finding, PR #340).
  Future<Pact> _resolvePredecessorConflict(Pact pact) async {
    final predecessorId = pact.predecessorPactId;
    if (predecessorId == null) return pact;

    final existingSuccessor = await _pactRepository.getSuccessor(predecessorId);
    if (existingSuccessor == null) return pact;

    DateTime effectiveCreatedAt(Pact p) => p.createdAt ?? p.startDate;
    final existingCreatedAt = effectiveCreatedAt(existingSuccessor);
    final incomingCreatedAt = effectiveCreatedAt(pact);

    final existingWins = existingCreatedAt.isAfter(incomingCreatedAt) ||
        (existingCreatedAt.isAtSameMomentAs(incomingCreatedAt) && existingSuccessor.id.compareTo(pact.id) > 0);

    if (existingWins) {
      // Existing local successor wins — the incoming remote record loses its link.
      return pact.copyWith(clearPredecessorPactId: true);
    }

    // Incoming remote successor wins — clear the existing local successor's link.
    await _pactRepository.updatePact(existingSuccessor.copyWith(clearPredecessorPactId: true));
    return pact;
  }

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

  Future<void> _mergeRemotePactBreak(Map<String, dynamic> doc, DateTime now) => _mergeRemoteRecord<PactBreak>(
        doc: doc,
        now: now,
        getLocal: _pactBreakRepository.getBreakById,
        getSyncedAt: _pactBreakSyncRepository.getPactBreakSyncedAt,
        fromDocument: SyncMapper.pactBreakFromDocument,
        insert: _pactBreakRepository.saveBreak,
        update: _pactBreakRepository.updateBreak,
        markSynced: _pactBreakSyncRepository.markPactBreakSynced,
      );

  // Singleton record (no `id`), so this doesn't reuse [_mergeRemoteRecord]:
  // same LWW rule (remote `updated_at` > local `synced_at` wins; dirty local
  // always wins) but "not found locally" and "found locally" both resolve to
  // the same upsert call rather than separate insert/update methods.
  Future<void> _mergeRemoteUserProfile(Map<String, dynamic> doc, DateTime now) async {
    final local = await _userProfileRepository.getProfile();

    if (local == null) {
      await _userProfileRepository.saveProfile(SyncMapper.userProfileFromDocument(doc));
      await _userProfileSyncRepository.markUserProfileSynced(now);
      return;
    }

    final localSyncedAt = await _userProfileSyncRepository.getUserProfileSyncedAt();
    if (localSyncedAt == null) return; // dirty → keep local (never resolved by "remote wins")

    final remoteUpdatedAt = SyncMapper.updatedAtFromDocument(doc);
    if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localSyncedAt)) return; // not newer

    await _userProfileRepository.saveProfile(SyncMapper.userProfileFromDocument(doc));
    await _userProfileSyncRepository.markUserProfileSynced(now);
  }

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
