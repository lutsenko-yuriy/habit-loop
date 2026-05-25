// End-to-end flows exercising sign-in data sync:
//   1. anonymous user with no data → signs in → remote pact appears
//   2. anonymous user with local data → signs in → remote + local both visible
//
// Run with: flutter test integration_test/sync_on_login_flow_test.dart -d <device>
// Run on host: flutter test integration_test/sync_on_login_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/force_sync_result.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import '../test/infrastructure/sync/fake_sync_service.dart';
import 'harness.dart';

/// Disables the onboarding auto-advance timer (RC value < _minAutoAdvanceSeconds=5).
final _noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

// Fixed clock: 5 minutes before the 08:00 remote showup window so the
// auto-fail check (now > scheduledAt + duration) never triggers, and also
// well before the 19:00 local showup in the merge scenario.
final _testNow = DateTime(2099, 7, 1, 7, 55);

// Pact + showup that the seeding sync service injects into the repos when
// pullRemoteChanges() is called (simulating a Firestore fetch after sign-in).
const _pactId = 'remote-pact-1';
final _remotePact = Pact(
  id: _pactId,
  habitName: 'Morning Run',
  startDate: DateTime(2099, 7, 1),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: DateTime(2099, 7, 1),
);
const _showupId = '${_pactId}_20990701T080000_0';
final _remoteShowup = Showup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 7, 1, 8, 0),
  duration: const Duration(minutes: 30),
  status: ShowupStatus.pending,
);

// Local pact that exists in the repo BEFORE sign-in (created anonymously).
// Scheduled at 19:00 so it does not conflict with the 08:00 remote showup
// and is not auto-failed by the 07:55 fixed clock.
const _localPactId = 'local-pact-1';
final _localPact = Pact(
  id: _localPactId,
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 7, 1),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 19)),
  status: PactStatus.active,
  createdAt: DateTime(2099, 7, 1),
);
const _localShowupId = '${_localPactId}_20990701T190000_0';
final _localShowup = Showup(
  id: _localShowupId,
  pactId: _localPactId,
  scheduledAt: DateTime(2099, 7, 1, 19, 0),
  duration: const Duration(minutes: 20),
  status: ShowupStatus.pending,
);

/// Sync service that seeds in-memory repos when [pullRemoteChanges] is called,
/// simulating the data that would be fetched from Firestore after sign-in.
class _SeedingSyncService extends FakeSyncService {
  _SeedingSyncService(this._pactRepo, this._showupRepo);

  final InMemoryPactRepository _pactRepo;
  final InMemoryShowupRepository _showupRepo;

  @override
  Future<void> pullRemoteChanges() async {
    await super.pullRemoteChanges();
    await _pactRepo.savePact(_remotePact);
    await _showupRepo.saveShowups([_remoteShowup]);
  }
}

// ---------------------------------------------------------------------------
// Spy helpers for the dirty-records-uploaded-after-sign-in test
// ---------------------------------------------------------------------------

/// Spy [PactSyncRepository] that holds a pre-seeded dirty list and records
/// nothing in storage — sufficient for verifying that [forceSyncAll] reads
/// from whatever [pactSyncRepositoryProvider] is wired to.
class _SpyPactSyncRepository implements PactSyncRepository {
  final _dirty = <Pact>[];

  void seedAsDirty(Pact pact) => _dirty.add(pact);

  @override
  Future<List<Pact>> getDirtyPacts() async => List.unmodifiable(_dirty);

  @override
  Future<void> markPactSynced(String pactId, DateTime syncedAt) async {
    _dirty.removeWhere((p) => p.id == pactId);
  }

  @override
  Future<DateTime?> getPactSyncedAt(String pactId) async => null;

  @override
  Future<void> markAllPactsDirty() async {}
}

/// Spy [ShowupSyncRepository] — mirrors [_SpyPactSyncRepository].
class _SpyShowupSyncRepository implements ShowupSyncRepository {
  final _dirty = <Showup>[];

  void seedAsDirty(Showup showup) => _dirty.add(showup);

  @override
  Future<List<Showup>> getDirtyShowups() async => List.unmodifiable(_dirty);

  @override
  Future<void> markShowupSynced(String showupId, DateTime syncedAt) async {
    _dirty.removeWhere((s) => s.id == showupId);
  }

  @override
  Future<DateTime?> getShowupSyncedAt(String showupId) async => null;

  @override
  Future<void> markAllShowupsDirty() async {}
}

/// Sync service that, in [forceSyncAll], reads the spy repos and records which
/// IDs were found dirty — without touching Firestore.
class _DirtyCapturingSyncService extends FakeSyncService {
  _DirtyCapturingSyncService(this._pactSyncRepo, this._showupSyncRepo);

  final _SpyPactSyncRepository _pactSyncRepo;
  final _SpyShowupSyncRepository _showupSyncRepo;

  final flushedPactIds = <String>[];
  final flushedShowupIds = <String>[];

  @override
  Future<ForceSyncResult> forceSyncAll() async {
    for (final p in await _pactSyncRepo.getDirtyPacts()) {
      flushedPactIds.add(p.id);
    }
    for (final s in await _showupSyncRepo.getDirtyShowups()) {
      flushedShowupIds.add(s.id);
    }
    return super.forceSyncAll();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Sync on login flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('sign-in pulls remote data and shows it on the dashboard', (tester) async {
      h = await AppHarness.create(
        tester,
        initiallyAnonymous: true,
        syncServiceFactory: (pactRepo, showupRepo) => _SeedingSyncService(pactRepo, showupRepo),
        extraOverrides: [
          _noAutoAdvance,
          // Pin the clock so the seeded showup is not auto-failed.
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
      );
      final strings = l10n(tester);

      // ── 1. Onboarding carousel shown (anonymous user, no data yet) ───────
      // The carousel replaces the old "No pacts yet" empty state.
      await waitFor(tester, find.text(strings.onboardingSlide0Title));
      expect(find.text('Morning Run'), findsNothing);

      // ── 2. Tap "Sign in with Google" in the carousel ─────────────────────
      // The carousel shows this button only when isAnonymous is true,
      // confirming auth has propagated. Tapping it calls
      // SyncStatusViewModel.linkWithGoogle() → _SeedingSyncService.pullRemoteChanges()
      // seeds the in-memory repos → dashboard reloads with remote data.
      await waitFor(tester, find.text(strings.signInWithGoogle));
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump(); // linkWithGoogle() starts

      // ── 3. Wait for dashboard to reload with remote data ─────────────────
      await waitFor(tester, find.text('Morning Run'));
      expect(find.text('Morning Run'), findsOneWidget);
    });

    testWidgets('forceSyncAll reads dirty local records from the wired sync repos after sign-in', (tester) async {
      // Regression guard for HAB-73: main.dart was not passing pactSyncRepository
      // and showupSyncRepository to AppContainer.overrides(), so getDirtyPacts()
      // always returned [] from the noop defaults and local records were never
      // uploaded after sign-in.
      //
      // This test verifies the full sign-in → forceSyncAll → getDirtyPacts path
      // using spy repos so that a regression to noop defaults would break it.
      final pactSyncRepo = _SpyPactSyncRepository();
      final showupSyncRepo = _SpyShowupSyncRepository();
      late _DirtyCapturingSyncService capturer;

      h = await AppHarness.create(
        tester,
        initiallyAnonymous: true,
        syncServiceFactory: (_, __) {
          capturer = _DirtyCapturingSyncService(pactSyncRepo, showupSyncRepo);
          return capturer;
        },
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
          pactSyncRepositoryProvider.overrideWithValue(pactSyncRepo),
          showupSyncRepositoryProvider.overrideWithValue(showupSyncRepo),
        ],
        beforePump: (h) async {
          // Simulate records created while anonymous: present in the local
          // repos and marked dirty in the sync repos.
          await h.pactRepo.savePact(_localPact);
          await h.showupRepo.saveShowups([_localShowup]);
          pactSyncRepo.seedAsDirty(_localPact);
          showupSyncRepo.seedAsDirty(_localShowup);
        },
      );

      // ── 1. Dashboard shows the local pact; forceSyncAll not yet called ───
      await waitFor(tester, find.text('Evening Walk'));
      expect(capturer.forceSyncAllCount, isZero);

      // ── 2. Open sync status dialog and sign in ────────────────────────────
      await waitFor(tester, find.byIcon(Icons.cloud_off_outlined));
      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n(tester).signInWithGoogle));
      await tester.pump();

      // ── 3. Wait for the icon to flip to cloud_done (auth → synced state) ─
      await waitFor(tester, find.byIcon(Icons.cloud_done_outlined));

      // ── 4. forceSyncAll was called and found the dirty records ────────────
      expect(capturer.forceSyncAllCount, equals(1));
      expect(capturer.flushedPactIds, contains(_localPactId));
      expect(capturer.flushedShowupIds, contains(_localShowupId));
    });

    testWidgets('sign-in merges remote data with pre-existing local pacts', (tester) async {
      h = await AppHarness.create(
        tester,
        initiallyAnonymous: true,
        syncServiceFactory: (pactRepo, showupRepo) => _SeedingSyncService(pactRepo, showupRepo),
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
        // Seed a local pact that the anonymous user created before sign-in.
        beforePump: (h) async {
          await h.pactRepo.savePact(_localPact);
          await h.showupRepo.saveShowups([_localShowup]);
        },
      );
      final strings = l10n(tester);

      // ── 1. Dashboard shows local pact; remote pact is not present yet ────
      await waitFor(tester, find.text('Evening Walk'));
      expect(find.text('Evening Walk'), findsOneWidget);
      expect(find.text('Morning Run'), findsNothing);

      // ── 2. Open sync status dialog ────────────────────────────────────────
      await waitFor(tester, find.byIcon(Icons.cloud_off_outlined));
      await tester.tap(find.byKey(const Key('sync-status-button')));
      // Verify the dialog opened by checking the sign-in action is present
      // (platform-agnostic: Android shows AlertDialog, iOS shows CupertinoAlertDialog).
      await waitFor(tester, find.text(strings.signInWithGoogle));
      expect(find.text(strings.signInWithGoogle), findsOneWidget);

      // ── 3. Tap "Sign in with Google" ──────────────────────────────────────
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump(); // dialog pops + linkWithGoogle() starts

      // ── 4. Both pacts visible: local preserved, remote merged in ──────────
      await waitFor(tester, find.text('Morning Run'));
      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Evening Walk'), findsOneWidget);
    });
  });
}
