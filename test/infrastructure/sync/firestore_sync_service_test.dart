import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
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
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../infrastructure/auth/fake_auth_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeFirestoreClient implements FirestoreClient {
  final List<Map<String, dynamic>> upsertedPacts = [];
  final List<Map<String, dynamic>> upsertedShowups = [];
  bool throwOnNext = false;
  bool throwOnGetPacts = false;
  List<Map<String, dynamic>> remotePactDocs = [];
  List<Map<String, dynamic>> remoteShowupDocs = [];

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async {
    if (throwOnGetPacts) throw Exception('network error');
    return remotePactDocs;
  }

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => remoteShowupDocs;

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('network error');
    }
    upsertedPacts.add(data);
  }

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('network error');
    }
    upsertedShowups.add(data);
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {}

  @override
  Future<void> deleteShowup(String userId, String showupId) async {}
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
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => [];

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async => throw Exception('error');

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async =>
      throw Exception('error');

  @override
  Future<void> deletePact(String userId, String pactId) async {}

  @override
  Future<void> deleteShowup(String userId, String showupId) async {}
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Pact _pact(String id) => Pact(
      id: id,
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
    );

Showup _showup(String id) => Showup(
      id: id,
      pactId: 'p1',
      scheduledAt: DateTime(2026, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

Map<String, dynamic> _remotePactDoc(String id, {DateTime? updatedAt}) =>
    SyncMapper.pactToDocument(_pact(id), updatedAt: updatedAt);

Map<String, dynamic> _remoteShowupDoc(String id, {DateTime? updatedAt}) =>
    SyncMapper.showupToDocument(_showup(id), updatedAt: updatedAt);

FirestoreSyncService _makeService({
  _FakeFirestoreClient? client,
  FakeAuthService? auth,
  SyncCircuitBreaker? cb,
  List<Pact>? dirtyPacts,
  List<Showup>? dirtyShowups,
  Map<String, DateTime>? pactSyncedAts,
  Map<String, DateTime>? showupSyncedAts,
  PactRepository? pactRepository,
  ShowupRepository? showupRepository,
}) {
  return FirestoreSyncService(
    firestoreClient: client ?? _FakeFirestoreClient(),
    authService: auth ?? FakeAuthService(userId: 'user-1'),
    circuitBreaker: cb ?? SyncCircuitBreaker(),
    pactSyncRepository: _InMemoryPactSyncRepo(dirtyPacts ?? [], syncedAts: pactSyncedAts),
    showupSyncRepository: _InMemoryShowupSyncRepo(dirtyShowups ?? [], syncedAts: showupSyncedAts),
    pactRepository: pactRepository ?? InMemoryPactRepository(),
    showupRepository: showupRepository ?? InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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

  group('FirestoreSyncService.uploadPact — halfOpen flush trigger', () {
    test('triggers flushDirtyRecords when CB transitions halfOpen → closed', () async {
      // Set up: 1 dirty pact in repo, CB starts halfOpen (1 previous failure)
      final client = _FakeFirestoreClient();
      final dirtyPact = _pact('dirty-p');
      final dirtyPactSyncRepo = _InMemoryPactSyncRepo([dirtyPact]);
      final cb = SyncCircuitBreaker()..recordFailure(); // closed → halfOpen

      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: cb,
        pactSyncRepository: dirtyPactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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
    test('uploads all dirty pacts and showups', () async {
      final client = _FakeFirestoreClient();
      final svc = _makeService(
        client: client,
        dirtyPacts: [_pact('p1'), _pact('p2')],
        dirtyShowups: [_showup('s1')],
      );

      await svc.flushDirtyRecords();

      expect(client.upsertedPacts.map((d) => d['id']), containsAll(['p1', 'p2']));
      expect(client.upsertedShowups.map((d) => d['id']), contains('s1'));
    });

    test('stops early when CB transitions to open mid-flush', () async {
      // CB is halfOpen (1 failure). After 5 consecutive failures it goes open.
      final cb = SyncCircuitBreaker()..recordFailure(); // closed → halfOpen

      // Build 6 dirty pacts; client throws on every upload.
      final dirtyPacts = List.generate(6, (i) => _pact('p$i'));
      final throwingClient = _ThrowingFirestoreClient();

      final svc = FirestoreSyncService(
        firestoreClient: throwingClient,
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: cb,
        pactSyncRepository: _InMemoryPactSyncRepo(dirtyPacts),
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: pactRepo,
        showupRepository: InMemoryShowupRepository(),
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: showupRepo,
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: _InMemoryPactSyncRepo([]),
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository(),
        showupRepository: showupRepo,
      );

      await svc.pullRemoteChanges();

      expect(showupSyncRepo.synced, isEmpty);
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
  });

  group('FirestoreSyncService.forceSyncAll', () {
    test('marks all records dirty, flushes them, and returns 0 when all succeed', () async {
      final client = _FakeFirestoreClient();
      final pact = _pact('p1');
      final showup = _showup('s1');

      // Start with p1 and s1 as clean (synced) records
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

      final svc = FirestoreSyncService(
        firestoreClient: client,
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository([pact]),
        showupRepository: InMemoryShowupRepository([showup]),
      );

      final result = await svc.forceSyncAll();

      expect(client.upsertedPacts.map((d) => d['id']), contains('p1'));
      expect(client.upsertedShowups.map((d) => d['id']), contains('s1'));
      expect(result.attempted, equals(2)); // p1 + s1
      expect(result.pactsFailed, equals(0));
      expect(result.showupsFailed, equals(0));
    });

    test('returns count of records that failed to upload', () async {
      final pact = _pact('p1');
      final showup = _showup('s1');

      // Records start as clean — forceSyncAll marks them dirty then tries to flush.
      // _ThrowingFirestoreClient always throws, so both stay dirty.
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

      final svc = FirestoreSyncService(
        firestoreClient: _ThrowingFirestoreClient(),
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: pactSyncRepo,
        showupSyncRepository: showupSyncRepo,
        pactRepository: InMemoryPactRepository([pact]),
        showupRepository: InMemoryShowupRepository([showup]),
      );

      final result = await svc.forceSyncAll();

      // p1 failed as a pact, s1 failed as a showup — split by entity type.
      expect(result.attempted, equals(2));
      expect(result.pactsFailed, equals(1));
      expect(result.showupsFailed, equals(1));
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
        authService: FakeAuthService(userId: 'user-1'),
        circuitBreaker: SyncCircuitBreaker(),
        pactSyncRepository: throwingSyncRepo,
        showupSyncRepository: _InMemoryShowupSyncRepo([]),
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
      );

      final result = await svc.forceSyncAll();
      expect(result.attempted, equals(0));
      expect(result.pactsFailed, equals(0));
      expect(result.showupsFailed, equals(0));
    });
  });
}
