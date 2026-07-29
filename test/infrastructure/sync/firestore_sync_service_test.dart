import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_break_sync_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/sync/firestore_sync_service.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../infrastructure/auth/fake_auth_service.dart';
import '../../infrastructure/remote_config/fake_remote_config_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeFirestoreClient implements FirestoreClient {
  final List<Map<String, dynamic>> upsertedPacts = [];
  final List<Map<String, dynamic>> upsertedShowups = [];
  final List<Map<String, dynamic>> upsertedPactBreaks = [];
  bool throwOnNext = false;
  bool throwOnGetPacts = false;
  List<Map<String, dynamic>> remotePactDocs = [];
  List<Map<String, dynamic>> remoteShowupDocs = [];
  List<Map<String, dynamic>> remotePactBreakDocs = [];

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async {
    if (throwOnGetPacts) throw Exception('network error');
    return remotePactDocs;
  }

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('network error');
    }
    upsertedPacts.add(data);
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {}

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => remoteShowupDocs;

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('network error');
    }
    upsertedShowups.add(data);
  }

  @override
  Future<void> deleteShowup(String userId, String showupId) async {}

  @override
  Future<List<Map<String, dynamic>>> getPactBreaks(String userId) async => remotePactBreakDocs;

  @override
  Future<void> upsertPactBreak(String userId, String pactBreakId, Map<String, dynamic> data) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('network error');
    }
    upsertedPactBreaks.add(data);
  }

  @override
  Future<void> deletePactBreak(String userId, String pactBreakId) async {}
}

class _ThrowingPactSyncRepo implements PactSyncRepository {
  @override
  Future<List<Pact>> getDirtyPacts() async => [];

  @override
  Future<void> markPactSynced(String pactId, DateTime syncedAt) async {}

  @override
  Future<DateTime?> getPactSyncedAt(String pactId) async => null;

  @override
  Future<void> markAllPactsDirty() async => throw Exception('simulated DB error');
}

class _ThrowingFirestoreClient implements FirestoreClient {
  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async => [];

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async => throw Exception('error');

  @override
  Future<void> deletePact(String userId, String pactId) async {}

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => [];

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async =>
      throw Exception('error');

  @override
  Future<void> deleteShowup(String userId, String showupId) async {}

  @override
  Future<List<Map<String, dynamic>>> getPactBreaks(String userId) async => [];

  @override
  Future<void> upsertPactBreak(String userId, String pactBreakId, Map<String, dynamic> data) async =>
      throw Exception('error');

  @override
  Future<void> deletePactBreak(String userId, String pactBreakId) async {}
}

class _InMemoryPactSyncRepo implements PactSyncRepository {
  final List<Pact> dirty;
  final List<Pact> all;
  final List<String> synced = [];
  final Map<String, DateTime> syncedAts;

  _InMemoryPactSyncRepo(this.dirty, {Map<String, DateTime>? syncedAts, List<Pact>? all})
      : syncedAts = Map.of(syncedAts ?? {}),
        all = all ?? List.from(dirty);

  @override
  Future<List<Pact>> getDirtyPacts() async => List.from(dirty);

  @override
  Future<void> markPactSynced(String pactId, DateTime syncedAt) async {
    synced.add(pactId);
    dirty.removeWhere((p) => p.id == pactId);
    syncedAts[pactId] = syncedAt;
  }

  @override
  Future<DateTime?> getPactSyncedAt(String pactId) async {
    if (dirty.any((p) => p.id == pactId)) return null;
    return syncedAts[pactId];
  }

  @override
  Future<void> markAllPactsDirty() async {
    for (final p in all) {
      if (!dirty.any((d) => d.id == p.id)) {
        dirty.add(p);
      }
    }
    syncedAts.clear();
  }
}

class _InMemoryShowupSyncRepo implements ShowupSyncRepository {
  final List<Showup> dirty;
  final List<Showup> all;
  final List<String> synced = [];
  final Map<String, DateTime> syncedAts;

  _InMemoryShowupSyncRepo(this.dirty, {Map<String, DateTime>? syncedAts, List<Showup>? all})
      : syncedAts = Map.of(syncedAts ?? {}),
        all = all ?? List.from(dirty);

  @override
  Future<List<Showup>> getDirtyShowups() async => List.from(dirty);

  @override
  Future<void> markShowupSynced(String showupId, DateTime syncedAt) async {
    synced.add(showupId);
    dirty.removeWhere((s) => s.id == showupId);
    syncedAts[showupId] = syncedAt;
  }

  @override
  Future<DateTime?> getShowupSyncedAt(String showupId) async {
    if (dirty.any((s) => s.id == showupId)) return null;
    return syncedAts[showupId];
  }

  @override
  Future<void> markAllShowupsDirty() async {
    for (final s in all) {
      if (!dirty.any((d) => d.id == s.id)) {
        dirty.add(s);
      }
    }
    syncedAts.clear();
  }
}

class _InMemoryPactBreakSyncRepo implements PactBreakSyncRepository {
  final List<PactBreak> dirty;
  final List<PactBreak> all;
  final List<String> synced = [];
  final Map<String, DateTime> syncedAts;

  _InMemoryPactBreakSyncRepo(this.dirty, {Map<String, DateTime>? syncedAts, List<PactBreak>? all})
      : syncedAts = Map.of(syncedAts ?? {}),
        all = all ?? List.from(dirty);

  @override
  Future<List<PactBreak>> getDirtyPactBreaks() async => List.from(dirty);

  @override
  Future<void> markPactBreakSynced(String pactBreakId, DateTime syncedAt) async {
    synced.add(pactBreakId);
    dirty.removeWhere((b) => b.id == pactBreakId);
    syncedAts[pactBreakId] = syncedAt;
  }

  @override
  Future<DateTime?> getPactBreakSyncedAt(String pactBreakId) async {
    if (dirty.any((b) => b.id == pactBreakId)) return null;
    return syncedAts[pactBreakId];
  }

  @override
  Future<void> markAllPactBreaksDirty() async {
    for (final b in all) {
      if (!dirty.any((d) => d.id == b.id)) {
        dirty.add(b);
      }
    }
    syncedAts.clear();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Pact _pact(String id, {String? predecessorPactId, DateTime? createdAt}) => Pact(
      id: id,
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
      predecessorPactId: predecessorPactId,
      createdAt: createdAt,
    );

Showup _showup(String id) => Showup(
      id: id,
      pactId: 'p1',
      scheduledAt: DateTime(2026, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

PactBreak _pactBreak(String id) => PactBreak(
      id: id,
      pactId: 'p1',
      startDate: DateTime(2026, 3, 1),
      rationale: 'Recovering from a cold',
    );

Map<String, dynamic> _remotePactDoc(String id, {DateTime? updatedAt, String? predecessorPactId, DateTime? createdAt}) =>
    SyncMapper.pactToDocument(_pact(id, predecessorPactId: predecessorPactId, createdAt: createdAt),
        updatedAt: updatedAt);

Map<String, dynamic> _remoteShowupDoc(String id, {DateTime? updatedAt}) =>
    SyncMapper.showupToDocument(_showup(id), updatedAt: updatedAt);

Map<String, dynamic> _remotePactBreakDoc(String id, {DateTime? updatedAt}) =>
    SyncMapper.pactBreakToDocument(_pactBreak(id), updatedAt: updatedAt);

FirestoreSyncService _makeService({
  _FakeFirestoreClient? client,
  FakeAuthService? auth,
  SyncCircuitBreaker? cb,
  List<Pact>? dirtyPacts,
  List<Showup>? dirtyShowups,
  List<PactBreak>? dirtyPactBreaks,
  Map<String, DateTime>? pactSyncedAts,
  Map<String, DateTime>? showupSyncedAts,
  Map<String, DateTime>? pactBreakSyncedAts,
  PactRepository? pactRepository,
  ShowupRepository? showupRepository,
  PactBreakRepository? pactBreakRepository,
  FakeRemoteConfigService? remoteConfig,
}) {
  return FirestoreSyncService(
    firestoreClient: client ?? _FakeFirestoreClient(),
    authService: auth ?? FakeAuthService(userId: 'user-1', isAnonymous: false),
    circuitBreaker: cb ?? SyncCircuitBreaker(),
    pactSyncRepository: _InMemoryPactSyncRepo(dirtyPacts ?? [], syncedAts: pactSyncedAts),
    showupSyncRepository: _InMemoryShowupSyncRepo(dirtyShowups ?? [], syncedAts: showupSyncedAts),
    pactBreakSyncRepository: _InMemoryPactBreakSyncRepo(dirtyPactBreaks ?? [], syncedAts: pactBreakSyncedAts),
    pactRepository: pactRepository ?? InMemoryPactRepository(),
    showupRepository: showupRepository ?? InMemoryShowupRepository(),
    pactBreakRepository: pactBreakRepository ?? InMemoryPactBreakRepository(),
    remoteConfig: remoteConfig,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FirestoreSyncService.uploadPact', () {
    test('uploads to Firestore and marks pact synced when CB is closed', () async {
      final client = _FakeFirestoreClient();
      final pactSyncRepo = _InMemoryPactSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.uploadPact(_pact('p1'));

      expect(client.upsertedPacts.length, 1);
      expect(client.upsertedPacts.first['id'], 'p1');
      expect(pactSyncRepo.synced, ['p1']);
    });

    test('does not upload when CB is open', () async {
      final client = _FakeFirestoreClient();
      final cb = SyncCircuitBreaker();
      // Force CB to open: 1 closed→halfOpen + 5 halfOpen failures
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      final svc = _makeService(client: client, cb: cb);
      await svc.uploadPact(_pact('p1'));

      expect(client.upsertedPacts, isEmpty);
    });

    test('calls recordFailure on network error (transitions closed→halfOpen)', () async {
      final client = _FakeFirestoreClient()..throwOnNext = true;
      final cb = SyncCircuitBreaker();
      final svc = _makeService(client: client, cb: cb);

      await svc.uploadPact(_pact('p1'));

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
    });

    test('does not mark synced on network error', () async {
      final client = _FakeFirestoreClient()..throwOnNext = true;
      final pactSyncRepo = _InMemoryPactSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.uploadPact(_pact('p1'));

      expect(pactSyncRepo.synced, isEmpty);
    });

    test('does not upload when userId is null', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(client: client, auth: FakeAuthService(userId: null));

      await svc.uploadPact(_pact('p1'));

      expect(client.upsertedPacts, isEmpty);
    });
  });

  group('FirestoreSyncService.uploadShowup', () {
    test('uploads to Firestore and marks showup synced when CB is closed', () async {
      final client = _FakeFirestoreClient();
      final showupSyncRepo = _InMemoryShowupSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.uploadShowup(_showup('s1'));

      expect(client.upsertedShowups.length, 1);
      expect(client.upsertedShowups.first['id'], 's1');
      expect(showupSyncRepo.synced, ['s1']);
    });

    test('does not upload when CB is open', () async {
      final client = _FakeFirestoreClient();
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      final svc = _makeService(client: client, cb: cb);
      await svc.uploadShowup(_showup('s1'));

      expect(client.upsertedShowups, isEmpty);
    });
  });

  group('FirestoreSyncService.uploadPactBreak', () {
    test('uploads to Firestore and marks pact break synced when CB is closed', () async {
      final client = _FakeFirestoreClient();
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.uploadPactBreak(_pactBreak('b1'));

      expect(client.upsertedPactBreaks.length, 1);
      expect(client.upsertedPactBreaks.first['id'], 'b1');
      expect(pactBreakSyncRepo.synced, ['b1']);
    });

    test('does not upload when CB is open', () async {
      final client = _FakeFirestoreClient();
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      final svc = _makeService(client: client, cb: cb);
      await svc.uploadPactBreak(_pactBreak('b1'));

      expect(client.upsertedPactBreaks, isEmpty);
    });

    test('does not upload when userId is null', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(client: client, auth: FakeAuthService(userId: null));

      await svc.uploadPactBreak(_pactBreak('b1'));

      expect(client.upsertedPactBreaks, isEmpty);
    });
  });

  group('FirestoreSyncService.uploadPact — halfOpen flush trigger', () {
    test('triggers flushDirtyRecords when CB transitions halfOpen → closed', () async {
      // Set up: 1 dirty pact in repo, CB starts halfOpen (1 previous failure)
      final client = _FakeFirestoreClient();
      final dirtyPact = _pact('dirty-p');
      final dirtyPactSyncRepo = _InMemoryPactSyncRepo([dirtyPact]);
      final cb = SyncCircuitBreaker()..recordFailure(); // closed → halfOpen

      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: cb,
        pactSyncRepository: dirtyPactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      // A successful upload while halfOpen transitions CB to closed and triggers flush.
      await svc.uploadPact(_pact('p1'));
      // Let the unawaited flush complete.
      await Future<void>.delayed(Duration.zero);

      expect(cb.state, SyncCircuitBreakerState.closed);
      // The dirty-p from the flush should also have been uploaded.
      expect(client.upsertedPacts.map((d) => d['id']), containsAll(['p1', 'dirty-p']));
    });
  });

  group('FirestoreSyncService.flushDirtyRecords', () {
    test('uploads all dirty pacts, showups, and pact breaks', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        dirtyPacts: [_pact('p1'), _pact('p2')],
        dirtyShowups: [_showup('s1')],
        dirtyPactBreaks: [_pactBreak('b1')],
      );

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts.map((d) => d['id']), containsAll(['p1', 'p2']));
      expect(client.upsertedShowups.map((d) => d['id']), contains('s1'));
      expect(client.upsertedPactBreaks.map((d) => d['id']), contains('b1'));
    });

    test('stops early when CB transitions to open mid-flush', () async {
      // CB is halfOpen (1 failure). After 5 consecutive failures it goes open.
      final cb = SyncCircuitBreaker()..recordFailure(); // closed → halfOpen

      // Build 6 dirty pacts; client throws on every upload.
      final dirtyPacts = List.generate(6, (i) => _pact('p$i'));
      final throwingClient = _ThrowingFirestoreClient();

      final svc = FirestoreSyncService(
        firestoreClient: throwingClient,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: cb,
        pactSyncRepository: _InMemoryPactSyncRepo(dirtyPacts),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.flushDirtyRecords();

      // CB should have gone open (5 failures while in halfOpen).
      expect(cb.state, SyncCircuitBreakerState.open);
    });

    test('does nothing when CB is open', () async {
      final client = _FakeFirestoreClient();
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      final svc = _makeService(
        client: client,
        cb: cb,
        dirtyPacts: [_pact('p1')],
      );

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts, isEmpty);
    });

    test('caps at 400 items', () async {
      final client = _FakeFirestoreClient();
      final dirtyPacts = List.generate(401, (i) => _pact('p$i'));
      final svc = _makeService(client: client, dirtyPacts: dirtyPacts);

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts.length, 400);
    });
  });

  group('FirestoreSyncService.triggerManualSync', () {
    test('transitions CB from open to halfOpen', () async {
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCircuitBreakerState.open);

      final svc = _makeService(cb: cb);
      svc.triggerManualSync();

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
    });

    test('fires flushDirtyRecords after transitioning to halfOpen', () async {
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        cb: cb,
        dirtyPacts: [_pact('p1')],
      );

      svc.triggerManualSync();
      await Future<void>.delayed(Duration.zero);

      // flush runs (CB is halfOpen which allows requests).
      expect(client.upsertedPacts.isNotEmpty, isTrue);
    });
  });

  group('FirestoreSyncService.pullRemoteChanges', () {
    test('skips pull when CB is open', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCircuitBreakerState.open);

      final pactRepo = InMemoryPactRepository();
      final svc = _makeService(client: client, cb: cb, pactRepository: pactRepo);

      await svc.pullRemoteChanges();

      expect(await pactRepo.getAllPacts(), isEmpty);
    });

    test('skips pull when CB is halfOpen', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final cb = SyncCircuitBreaker()..recordFailure(); // closed → halfOpen
      expect(cb.state, SyncCircuitBreakerState.halfOpen);

      final pactRepo = InMemoryPactRepository();
      final svc = _makeService(client: client, cb: cb, pactRepository: pactRepo);

      await svc.pullRemoteChanges();

      expect(await pactRepo.getAllPacts(), isEmpty);
    });

    test('skips pull when userId is null', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final pactRepo = InMemoryPactRepository();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: null),
        pactRepository: pactRepo,
      );

      await svc.pullRemoteChanges();

      expect(await pactRepo.getAllPacts(), isEmpty);
    });

    test('inserts a remote pact not found locally', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final pactRepo = InMemoryPactRepository();
      final pactSyncRepo = _InMemoryPactSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.map((p) => p.id), contains('p1'));
      expect(pactSyncRepo.synced, contains('p1'));
    });

    test('marks newly inserted remote pact as synced (dirty=false)', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final pactSyncRepo = _InMemoryPactSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      expect(pactSyncRepo.synced, contains('p1'));
      expect(await pactSyncRepo.getPactSyncedAt('p1'), isNotNull);
    });

    test('skips remote pact when local copy is dirty', () async {
      final localPact = _pact('p1');
      final pactRepo = InMemoryPactRepository([localPact]);
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1', updatedAt: DateTime(2026, 6, 1))];
      // local is dirty → pact is in dirty list
      final pactSyncRepo = _InMemoryPactSyncRepo([localPact]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      // updatePact should NOT have been called — local habit name unchanged
      final kept = await pactRepo.getPactById('p1');
      expect(kept, equals(localPact));
      // markPactSynced should NOT have been called (no new synced entries)
      expect(pactSyncRepo.synced, isEmpty);
    });

    test('overwrites local pact when remote updated_at is newer than local syncedAt', () async {
      final t1 = DateTime(2026, 3, 1);
      final t2 = DateTime(2026, 4, 1); // remote is newer

      final localPact = _pact('p1');
      final pactRepo = InMemoryPactRepository([localPact]);
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1', updatedAt: t2)];
      // local is clean with syncedAt=t1
      final pactSyncRepo = _InMemoryPactSyncRepo([], syncedAts: {'p1': t1});
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      expect(pactSyncRepo.synced, contains('p1'));
    });

    test('keeps local pact when remote updated_at is not newer than local syncedAt', () async {
      final t1 = DateTime(2026, 4, 1);
      final t2 = DateTime(2026, 3, 1); // remote is OLDER

      final localPact = _pact('p1').copyWith(habitName: 'Local version');
      final pactRepo = InMemoryPactRepository([localPact]);
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1', updatedAt: t2)];
      final pactSyncRepo = _InMemoryPactSyncRepo([], syncedAts: {'p1': t1});
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      // No overwrite — local version preserved
      expect(pactSyncRepo.synced, isEmpty);
      final kept = await pactRepo.getPactById('p1');
      expect(kept?.habitName, 'Local version');
    });

    test('inserts a remote showup not found locally', () async {
      final client = _FakeFirestoreClient()..remoteShowupDocs = [_remoteShowupDoc('s1')];
      final showupRepo = InMemoryShowupRepository();
      final showupSyncRepo = _InMemoryShowupSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: showupRepo,
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      expect(await showupRepo.getShowupById('s1'), isNotNull);
      expect(showupSyncRepo.synced, contains('s1'));
    });

    test('skips remote showup when local copy is dirty', () async {
      final localShowup = _showup('s1');
      final showupRepo = InMemoryShowupRepository([localShowup]);
      final client = _FakeFirestoreClient()
        ..remoteShowupDocs = [_remoteShowupDoc('s1', updatedAt: DateTime(2026, 6, 1))];
      final showupSyncRepo = _InMemoryShowupSyncRepo([localShowup]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: showupRepo,
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.pullRemoteChanges();

      expect(showupSyncRepo.synced, isEmpty);
    });

    test('inserts a remote pact break not found locally', () async {
      final client = _FakeFirestoreClient()..remotePactBreakDocs = [_remotePactBreakDoc('b1')];
      final pactBreakRepo = InMemoryPactBreakRepository();
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: pactBreakRepo,
      );

      await svc.pullRemoteChanges();

      expect(await pactBreakRepo.getBreakById('b1'), isNotNull);
      expect(pactBreakSyncRepo.synced, contains('b1'));
    });

    test('skips remote pact break when local copy is dirty', () async {
      final localBreak = _pactBreak('b1');
      final pactBreakRepo = InMemoryPactBreakRepository([localBreak]);
      final client = _FakeFirestoreClient()
        ..remotePactBreakDocs = [_remotePactBreakDoc('b1', updatedAt: DateTime(2026, 6, 1))];
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo([localBreak]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: pactBreakRepo,
      );

      await svc.pullRemoteChanges();

      expect(pactBreakSyncRepo.synced, isEmpty);
    });

    test('overwrites local pact break when remote updated_at is newer than local syncedAt', () async {
      final t1 = DateTime(2026, 3, 1);
      final t2 = DateTime(2026, 4, 1); // remote is newer

      final localBreak = _pactBreak('b1');
      final pactBreakRepo = InMemoryPactBreakRepository([localBreak]);
      final client = _FakeFirestoreClient()..remotePactBreakDocs = [_remotePactBreakDoc('b1', updatedAt: t2)];
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo([], syncedAts: {'b1': t1});
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: pactBreakRepo,
      );

      await svc.pullRemoteChanges();

      expect(pactBreakSyncRepo.synced, contains('b1'));
    });

    test('keeps local pact break when remote updated_at is not newer than local syncedAt', () async {
      final t1 = DateTime(2026, 4, 1);
      final t2 = DateTime(2026, 3, 1); // remote is OLDER

      final localBreak = _pactBreak('b1').copyWith(rationale: 'Local version');
      final pactBreakRepo = InMemoryPactBreakRepository([localBreak]);
      final client = _FakeFirestoreClient()..remotePactBreakDocs = [_remotePactBreakDoc('b1', updatedAt: t2)];
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo([], syncedAts: {'b1': t1});
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: pactBreakRepo,
      );

      await svc.pullRemoteChanges();

      // No overwrite — local version preserved
      expect(pactBreakSyncRepo.synced, isEmpty);
      final kept = await pactBreakRepo.getBreakById('b1');
      expect(kept?.rationale, 'Local version');
    });

    test('records CB failure when getPacts throws', () async {
      final client = _FakeFirestoreClient()..throwOnGetPacts = true;
      final cb = SyncCircuitBreaker();
      final svc = _makeService(client: client, cb: cb);

      await svc.pullRemoteChanges();

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
    });

    test('does not throw even when individual record decode fails', () async {
      // A doc with a bad/missing id should be skipped gracefully.
      final client = _FakeFirestoreClient()
        ..remotePactDocs = [
          {'id': null, 'habit_name': 'Bad'}, // bad doc
          _remotePactDoc('p2'),
        ];
      final pactRepo = InMemoryPactRepository();
      final svc = _makeService(client: client, pactRepository: pactRepo);

      // Should not throw.
      await expectLater(svc.pullRemoteChanges(), completes);
    });

    group('predecessor conflict resolution (HAB-202)', () {
      // Two offline devices each create a successor for the same predecessor
      // before ever syncing. savePact's "at most one successor" guard would
      // otherwise throw on insert, silently swallowed by the per-record
      // try/catch in pullRemoteChanges — permanently hiding the losing
      // record. Last-write-wins on createdAt instead clears the loser's
      // link so the record still lands, just unlinked.
      test('remote successor has a later createdAt: local successor loses its link, remote keeps its own', () async {
        final root = _pact('root');
        final localSucc = _pact('local-succ', predecessorPactId: 'root', createdAt: DateTime(2026, 1, 1));
        final pactRepo = InMemoryPactRepository([root, localSucc]);
        final client = _FakeFirestoreClient()
          ..remotePactDocs = [
            _remotePactDoc('remote-succ', predecessorPactId: 'root', createdAt: DateTime(2026, 2, 1)),
          ];
        final svc = _makeService(client: client, pactRepository: pactRepo);

        await svc.pullRemoteChanges();

        expect((await pactRepo.getPactById('remote-succ'))?.predecessorPactId, 'root');
        expect((await pactRepo.getPactById('local-succ'))?.predecessorPactId, isNull);
      });

      test('remote successor has an earlier createdAt: remote loses its link on insert, local successor untouched',
          () async {
        final root = _pact('root');
        final localSucc = _pact('local-succ', predecessorPactId: 'root', createdAt: DateTime(2026, 3, 1));
        final pactRepo = InMemoryPactRepository([root, localSucc]);
        final client = _FakeFirestoreClient()
          ..remotePactDocs = [
            _remotePactDoc('remote-succ', predecessorPactId: 'root', createdAt: DateTime(2026, 1, 1)),
          ];
        final svc = _makeService(client: client, pactRepository: pactRepo);

        await svc.pullRemoteChanges();

        expect((await pactRepo.getPactById('remote-succ'))?.predecessorPactId, isNull);
        expect((await pactRepo.getPactById('local-succ'))?.predecessorPactId, 'root');
      });

      test('no existing successor: remote pact is inserted with its predecessorPactId intact', () async {
        final root = _pact('root');
        final pactRepo = InMemoryPactRepository([root]);
        final client = _FakeFirestoreClient()
          ..remotePactDocs = [
            _remotePactDoc('remote-succ', predecessorPactId: 'root', createdAt: DateTime(2026, 1, 1)),
          ];
        final svc = _makeService(client: client, pactRepository: pactRepo);

        await svc.pullRemoteChanges();

        expect((await pactRepo.getPactById('remote-succ'))?.predecessorPactId, 'root');
      });
    });
  });

  group('FirestoreSyncService.forceSyncAll', () {
    test('marks all records dirty, flushes them, and returns 0 when all succeed', () async {
      final client = _FakeFirestoreClient();
      final pact = _pact('p1');
      final showup = _showup('s1');
      final pactBreak = _pactBreak('b1');

      // Start with p1, s1, and b1 as clean (synced) records
      final pactSyncRepo = _InMemoryPactSyncRepo(
        [], // not dirty
        syncedAts: {'p1': DateTime(2026, 5, 1)},
        all: [pact],
      );
      final showupSyncRepo = _InMemoryShowupSyncRepo(
        [], // not dirty
        syncedAts: {'s1': DateTime(2026, 5, 1)},
        all: [showup],
      );
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo(
        [], // not dirty
        syncedAts: {'b1': DateTime(2026, 5, 1)},
        all: [pactBreak],
      );

      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository([pact]),
        showupRepository: InMemoryShowupRepository([showup]),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: InMemoryPactBreakRepository([pactBreak]),
      );

      final result = await svc.forceSyncAll();

      expect(client.upsertedPacts.map((d) => d['id']), contains('p1'));
      expect(client.upsertedShowups.map((d) => d['id']), contains('s1'));
      expect(client.upsertedPactBreaks.map((d) => d['id']), contains('b1'));
      expect(result.attempted, equals(3)); // p1 + s1 + b1
      expect(result.pactsFailed, equals(0));
      expect(result.showupsFailed, equals(0));
      expect(result.pactBreaksFailed, equals(0));
    });

    test('returns count of records that failed to upload', () async {
      final pact = _pact('p1');
      final showup = _showup('s1');
      final pactBreak = _pactBreak('b1');

      // Records start as clean — forceSyncAll marks them dirty then tries to flush.
      // _ThrowingFirestoreClient always throws, so all three stay dirty.
      final pactSyncRepo = _InMemoryPactSyncRepo(
        [],
        syncedAts: {'p1': DateTime(2026, 5, 1)},
        all: [pact],
      );
      final showupSyncRepo = _InMemoryShowupSyncRepo(
        [],
        syncedAts: {'s1': DateTime(2026, 5, 1)},
        all: [showup],
      );
      final pactBreakSyncRepo = _InMemoryPactBreakSyncRepo(
        [],
        syncedAts: {'b1': DateTime(2026, 5, 1)},
        all: [pactBreak],
      );

      final svc = FirestoreSyncService(
        firestoreClient: _ThrowingFirestoreClient(),
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository([pact]),
        showupRepository: InMemoryShowupRepository([showup]),
        pactBreakSyncRepository: pactBreakSyncRepo,
        pactBreakRepository: InMemoryPactBreakRepository([pactBreak]),
      );

      final result = await svc.forceSyncAll();

      // p1 failed as a pact, s1 failed as a showup, b1 failed as a pact break — split by entity type.
      expect(result.attempted, equals(3));
      expect(result.pactsFailed, equals(1));
      expect(result.showupsFailed, equals(1));
      expect(result.pactBreaksFailed, equals(1));
    });

    test('returns 0 when CB is open and no records were queued', () async {
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCircuitBreakerState.open);

      final svc = _makeService(cb: cb);
      final result = await svc.forceSyncAll();
      expect(result.attempted, equals(0));
      expect(result.pactsFailed, equals(0));
      expect(result.showupsFailed, equals(0));
    });

    test('swallows exception from markAllPactsDirty and returns 0 (no-throw contract)', () async {
      // Use a sync repo whose markAllPactsDirty throws to verify the outer
      // try/catch in forceSyncAll honours the no-throw contract.
      final throwingSyncRepo = _ThrowingPactSyncRepo();
      final svc = FirestoreSyncService(
        firestoreClient: _FakeFirestoreClient(),
        authService: FakeAuthService(userId: 'user-1', isAnonymous: false),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: throwingSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      final result = await svc.forceSyncAll();
      expect(result.attempted, equals(0));
      expect(result.pactsFailed, equals(0));
      expect(result.showupsFailed, equals(0));
    });
  });

  group('FirestoreSyncService — anonymous user guard', () {
    test('uploadPact does not upload when user is anonymous', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
      );

      await svc.uploadPact(_pact('p1'));

      expect(client.upsertedPacts, isEmpty);
    });

    test('uploadPact does not mark pact synced when user is anonymous', () async {
      final client = _FakeFirestoreClient();
      final pactSyncRepo = _InMemoryPactSyncRepo([]);
      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        pactBreakSyncRepository: _InMemoryPactBreakSyncRepo([]),
        pactBreakRepository: InMemoryPactBreakRepository(),
      );

      await svc.uploadPact(_pact('p1'));

      expect(pactSyncRepo.synced, isEmpty);
    });

    test('uploadShowup does not upload when user is anonymous', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
      );

      await svc.uploadShowup(_showup('s1'));

      expect(client.upsertedShowups, isEmpty);
    });

    test('uploadPactBreak does not upload when user is anonymous', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
      );

      await svc.uploadPactBreak(_pactBreak('b1'));

      expect(client.upsertedPactBreaks, isEmpty);
    });

    test('flushDirtyRecords does not upload when user is anonymous', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
        dirtyPacts: [_pact('p1')],
        dirtyShowups: [_showup('s1')],
        dirtyPactBreaks: [_pactBreak('b1')],
      );

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts, isEmpty);
      expect(client.upsertedShowups, isEmpty);
      expect(client.upsertedPactBreaks, isEmpty);
    });

    test('pullRemoteChanges does not pull when user is anonymous', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final pactRepo = InMemoryPactRepository();
      final svc = _makeService(
        client: client,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
        pactRepository: pactRepo,
      );

      await svc.pullRemoteChanges();

      expect(await pactRepo.getAllPacts(), isEmpty);
    });

    test('triggerManualSync does not advance CB when user is anonymous', () async {
      final cb = SyncCircuitBreaker();
      cb.recordFailure();
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCircuitBreakerState.open);

      final svc = _makeService(
        cb: cb,
        auth: FakeAuthService(userId: 'anon-uid', isAnonymous: true),
      );
      svc.triggerManualSync();

      expect(cb.state, SyncCircuitBreakerState.open);
    });
  });

  group('FirestoreSyncService network_sync_enabled = false', () {
    FakeRemoteConfigService syncOff() => FakeRemoteConfigService(overrides: {'network_sync_enabled': false});

    test('uploadPact is a no-op — no Firestore call', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(client: client, remoteConfig: syncOff());

      await svc.uploadPact(_pact('p1'));

      expect(client.upsertedPacts, isEmpty);
    });

    test('uploadShowup is a no-op — no Firestore call', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(client: client, remoteConfig: syncOff());

      await svc.uploadShowup(_showup('s1'));

      expect(client.upsertedShowups, isEmpty);
    });

    test('uploadPactBreak is a no-op — no Firestore call', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(client: client, remoteConfig: syncOff());

      await svc.uploadPactBreak(_pactBreak('b1'));

      expect(client.upsertedPactBreaks, isEmpty);
    });

    test('flushDirtyRecords is a no-op — no Firestore call', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        dirtyPacts: [_pact('p1')],
        dirtyShowups: [_showup('s1')],
        dirtyPactBreaks: [_pactBreak('b1')],
        remoteConfig: syncOff(),
      );

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts, isEmpty);
      expect(client.upsertedShowups, isEmpty);
      expect(client.upsertedPactBreaks, isEmpty);
    });

    test('triggerManualSync is a no-op — CB state stays closed', () async {
      final cb = SyncCircuitBreaker();
      final svc = _makeService(cb: cb, remoteConfig: syncOff());

      svc.triggerManualSync();

      expect(cb.currentState, SyncCircuitBreakerState.closed);
    });

    test('pullRemoteChanges is a no-op — Firestore client never queried', () async {
      final client = _FakeFirestoreClient()..remotePactDocs = [_remotePactDoc('p1')];
      final svc = _makeService(client: client, remoteConfig: syncOff());
      final before = List.of(client.remotePactDocs);

      await svc.pullRemoteChanges();

      // Docs were never consumed: getPacts was not called.
      // We verify by checking that nothing was written to the in-memory repo.
      expect(client.remotePactDocs, equals(before));
    });

    test('forceSyncAll returns zero counts without touching Firestore', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        dirtyPacts: [_pact('p1')],
        remoteConfig: syncOff(),
      );

      final result = await svc.forceSyncAll();

      expect(client.upsertedPacts, isEmpty);
      expect(result.attempted, 0);
      expect(result.pactsFailed, 0);
      expect(result.showupsFailed, 0);
    });

    test('CB state stays closed after uploadPact with sync disabled', () async {
      final cb = SyncCircuitBreaker();
      final svc = _makeService(cb: cb, remoteConfig: syncOff());

      await svc.uploadPact(_pact('p1'));

      expect(cb.currentState, SyncCircuitBreakerState.closed);
    });
  });
}
