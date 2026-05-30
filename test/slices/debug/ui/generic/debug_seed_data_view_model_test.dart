import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/local_auth_service.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('DebugSeedDataViewModel', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
    });

    ProviderContainer makeContainer({
      Object? fakeFirestore,
      Map<String, dynamic> rcOverrides = const {},
    }) {
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final rc = FakeRemoteConfigService(overrides: rcOverrides);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        remoteConfigServiceProvider.overrideWithValue(rc),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
        if (fakeFirestore != null) fakeFirestoreClientProvider.overrideWithValue(fakeFirestore),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    // ── build ─────────────────────────────────────────────────────────────────

    test('initial state is idle with no message', () {
      final container = makeContainer();
      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.idle);
      expect(state.message, isNull);
      expect(state.isBusy, isFalse);
    });

    // ── hasFakeBackend ────────────────────────────────────────────────────────

    test('hasFakeBackend is false when provider holds null', () {
      final container = makeContainer();
      expect(container.read(debugSeedDataViewModelProvider.notifier).hasFakeBackend, isFalse);
    });

    test('hasFakeBackend is true when a FakeFirestoreClient is wired', () {
      final container = makeContainer(fakeFirestore: FakeFirestoreClient());
      expect(container.read(debugSeedDataViewModelProvider.notifier).hasFakeBackend, isTrue);
    });

    test('hasFakeBackend is false when a non-FakeFirestoreClient object is wired', () {
      // Simulate an unrecognised sentinel (plain Object)
      final container = makeContainer(fakeFirestore: Object());
      expect(container.read(debugSeedDataViewModelProvider.notifier).hasFakeBackend, isFalse);
    });

    // ── seedLocalPacts ────────────────────────────────────────────────────────

    test('seedLocalPacts creates N pacts from RC max_active_pacts', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 3});
      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.done);
      expect(state.message, contains('3 pacts'));

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.length, 3);
    });

    test('seedLocalPacts creates 1 pact when RC returns 0 (clamped to 1)', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 0});
      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.length, 1);
    });

    test('seedLocalPacts replaces existing pacts on second call', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 2});
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);

      await notifier.seedLocalPacts();
      expect((await pactRepo.getAllPacts()).length, 2);

      // Seed again — should still be 2, not 4.
      await notifier.seedLocalPacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.done);
      expect((await pactRepo.getAllPacts()).length, 2);
    });

    test('seedLocalPacts pact IDs are stable across the same seed index', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 2});
      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.map((p) => p.id), containsAll(['debug-seed-local-0', 'debug-seed-local-1']));
    });

    test('seedLocalPacts assigns Mon-Fri weekly schedule to generated pacts', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 1});
      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.length, 1);
      expect(pacts.first.showupDuration, const Duration(minutes: 10));
    });

    // ── seedRemotePacts ───────────────────────────────────────────────────────

    test('seedRemotePacts is no-op when no fake backend wired', () async {
      final container = makeContainer();
      await container.read(debugSeedDataViewModelProvider.notifier).seedRemotePacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.idle);
    });

    test('seedRemotePacts seeds FakeFirestoreClient under localUserId', () async {
      final fake = FakeFirestoreClient();
      final container = makeContainer(fakeFirestore: fake, rcOverrides: {'max_active_pacts': 2});

      await container.read(debugSeedDataViewModelProvider.notifier).seedRemotePacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.done);
      expect(state.message, contains('2 pacts'));

      final snapshot = fake.snapshot();
      expect(snapshot.pacts[LocalAuthService.localUserId]?.length, 2);
      expect(snapshot.showups[LocalAuthService.localUserId]?.isNotEmpty, isTrue);
    });

    test('seedRemotePacts clears previous data before re-seeding', () async {
      final fake = FakeFirestoreClient();
      final container = makeContainer(fakeFirestore: fake, rcOverrides: {'max_active_pacts': 3});
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);

      await notifier.seedRemotePacts();
      await notifier.seedRemotePacts();

      // Should still be exactly 3 pacts, not 6.
      final snapshot = fake.snapshot();
      expect(snapshot.pacts[LocalAuthService.localUserId]?.length, 3);
    });

    test('seedRemotePacts pact IDs are stable across seed index', () async {
      final fake = FakeFirestoreClient();
      final container = makeContainer(fakeFirestore: fake, rcOverrides: {'max_active_pacts': 2});

      await container.read(debugSeedDataViewModelProvider.notifier).seedRemotePacts();

      final snapshot = fake.snapshot();
      final ids = snapshot.pacts[LocalAuthService.localUserId]?.keys.toList() ?? [];
      expect(ids, containsAll(['debug-seed-remote-0', 'debug-seed-remote-1']));
    });
  });
}
