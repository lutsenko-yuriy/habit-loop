import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/sync/firestore_sync_service.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';

import '../../infrastructure/auth/fake_auth_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeFirestoreClient implements FirestoreClient {
  final List<Map<String, dynamic>> upsertedPacts = [];
  final List<Map<String, dynamic>> upsertedShowups = [];
  bool throwOnNext = false;

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => [];

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
  final List<String> synced = [];

  _InMemoryPactSyncRepo(this.dirty);

  @override
  Future<List<Pact>> getDirtyPacts() async => List.from(dirty);

  @override
  Future<void> markPactSynced(String pactId, DateTime syncedAt) async {
    synced.add(pactId);
    dirty.removeWhere((p) => p.id == pactId);
  }
}

class _InMemoryShowupSyncRepo implements ShowupSyncRepository {
  final List<Showup> dirty;
  final List<String> synced = [];

  _InMemoryShowupSyncRepo(this.dirty);

  @override
  Future<List<Showup>> getDirtyShowups() async => List.from(dirty);

  @override
  Future<void> markShowupSynced(String showupId, DateTime syncedAt) async {
    synced.add(showupId);
    dirty.removeWhere((s) => s.id == showupId);
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

FirestoreSyncService _makeService({
  _FakeFirestoreClient? client,
  FakeAuthService? auth,
  SyncCircuitBreaker? cb,
  List<Pact>? dirtyPacts,
  List<Showup>? dirtyShowups,
}) {
  return FirestoreSyncService(
    firestoreClient: client ?? _FakeFirestoreClient(),
    authService: auth ?? FakeAuthService(userId: 'user-1'),
    circuitBreaker: cb ?? SyncCircuitBreaker(),
    pactSyncRepository: _InMemoryPactSyncRepo(dirtyPacts ?? []),
    showupSyncRepository: _InMemoryShowupSyncRepo(dirtyShowups ?? []),
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
}
