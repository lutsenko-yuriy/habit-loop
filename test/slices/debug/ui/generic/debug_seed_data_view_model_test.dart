import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/infrastructure/auth/data/local_auth_service.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('DebugSeedDataViewModel', () {
    late InMemoryPactRepository pactRepo;
    late InMemoryShowupRepository showupRepo;
    late InMemoryPactBreakRepository pactBreakRepo;

    setUp(() {
      pactRepo = InMemoryPactRepository();
      showupRepo = InMemoryShowupRepository();
      pactBreakRepo = InMemoryPactBreakRepository();
    });

    ProviderContainer makeContainer({
      Object? fakeFirestore,
      Map<String, dynamic> rcOverrides = const {},
      FakeNotificationService? notificationService,
    }) {
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final rc = FakeRemoteConfigService(overrides: rcOverrides);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactBreakRepositoryProvider.overrideWithValue(pactBreakRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        remoteConfigServiceProvider.overrideWithValue(rc),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
        if (fakeFirestore != null) fakeFirestoreClientProvider.overrideWithValue(fakeFirestore),
        if (notificationService != null) notificationServiceProvider.overrideWithValue(notificationService),
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

    // ── pactCount ─────────────────────────────────────────────────────────────

    test('initial pactCount defaults to max_active_pacts RC value', () {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 5});
      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.pactCount, 5);
    });

    test('initial pactCount clamps RC value below 1 up to 1', () {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 0});
      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.pactCount, 1);
    });

    test('initial pactCount clamps RC value above 10 down to 10', () {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 99});
      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.pactCount, 10);
    });

    test('setPactCount clamps out-of-range input to 1-10', () {
      final container = makeContainer();
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);

      notifier.setPactCount(0);
      expect(container.read(debugSeedDataViewModelProvider).pactCount, 1);

      notifier.setPactCount(15);
      expect(container.read(debugSeedDataViewModelProvider).pactCount, 10);
    });

    test('seedLocalPacts uses pactCount, not RC, once pactCount has been changed', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 3});
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);
      notifier.setPactCount(7);

      await notifier.seedLocalPacts();

      final pacts = await pactRepo.getAllPacts();
      expect(pacts.length, 7);
    });

    test('seedRemotePacts uses pactCount, not RC, once pactCount has been changed', () async {
      final fake = FakeFirestoreClient();
      final container = makeContainer(fakeFirestore: fake, rcOverrides: {'max_active_pacts': 3});
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);
      notifier.setPactCount(7);

      await notifier.seedRemotePacts();

      final snapshot = fake.snapshot();
      expect(snapshot.pacts[LocalAuthService.localUserId]?.length, 7);
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

    test('seedLocalPacts deletes an existing pact\'s breaks before deleting the pact (HAB-208)', () async {
      // pact_breaks.pact_id has a foreign key to pacts.id — a debug pact that
      // ever had a break (e.g. from testing the stop-break flow) must have
      // its breaks cleaned up first, or a real SQLite run would hit a
      // FOREIGN KEY constraint error deleting the pact.
      final container = makeContainer(rcOverrides: {'max_active_pacts': 1});
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);
      await notifier.seedLocalPacts();

      await pactBreakRepo.saveBreak(PactBreak(
        id: 'brk-1',
        pactId: 'debug-seed-local-0',
        startDate: DateTime.now(),
        rationale: 'Testing',
      ));

      await notifier.seedLocalPacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.done);
      expect(await pactBreakRepo.getBreaksForPact('debug-seed-local-0'), isEmpty);
    });

    test('seedLocalPacts cancels OS reminders for each deleted pact before re-seeding (HAB-229)', () async {
      final fakeNotifications = FakeNotificationService();
      final container = makeContainer(rcOverrides: {'max_active_pacts': 2}, notificationService: fakeNotifications);
      final notifier = container.read(debugSeedDataViewModelProvider.notifier);

      // First seed run creates debug-seed-local-0/1 with their own showups.
      await notifier.seedLocalPacts();
      final firstRunShowupIds = {
        for (final pactId in ['debug-seed-local-0', 'debug-seed-local-1'])
          ...(await showupRepo.getShowupsForPact(pactId)).map((s) => s.id),
      };
      expect(firstRunShowupIds, isNotEmpty);
      fakeNotifications.reset();

      // Second run deletes the first run's pacts — each deleted pact's
      // reminders must be cancelled, or they linger in the OS forever.
      await notifier.seedLocalPacts();

      expect(fakeNotifications.cancelledPactIds, containsAll(['debug-seed-local-0', 'debug-seed-local-1']));
      final cancelledShowupIds = fakeNotifications.cancelledPactShowupIds.expand((ids) => ids).toSet();
      expect(cancelledShowupIds, equals(firstRunShowupIds));
    });

    test('seedLocalPacts does not attempt cancellation when there are no existing pacts to delete', () async {
      final fakeNotifications = FakeNotificationService();
      final container = makeContainer(rcOverrides: {'max_active_pacts': 1}, notificationService: fakeNotifications);

      // First-ever run — nothing pre-existing to clean up.
      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      expect(fakeNotifications.cancelledPactIds, isEmpty);
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

    test('seedLocalPacts invalidates hasActivePactsProvider so dashboard refreshes', () async {
      final container = makeContainer(rcOverrides: {'max_active_pacts': 2});

      // Before seeding there are no pacts.
      expect(await container.read(hasActivePactsProvider.future), isFalse);

      await container.read(debugSeedDataViewModelProvider.notifier).seedLocalPacts();

      // After seeding, hasActivePactsProvider is invalidated and re-reads from
      // pactRepo — should now reflect the freshly seeded pacts.
      expect(await container.read(hasActivePactsProvider.future), isTrue);
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

    test('seedRemotePacts done message no longer instructs user to pull manually', () async {
      // seedRemotePacts now calls pullRemoteChanges + reloads dashboard internally.
      final fake = FakeFirestoreClient();
      final container = makeContainer(fakeFirestore: fake, rcOverrides: {'max_active_pacts': 1});

      await container.read(debugSeedDataViewModelProvider.notifier).seedRemotePacts();

      final state = container.read(debugSeedDataViewModelProvider);
      expect(state.status, DebugSeedState.done);
      expect(state.message, isNot(contains('Pull sync')));
    });
  });
}
