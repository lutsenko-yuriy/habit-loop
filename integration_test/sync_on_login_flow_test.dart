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
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/sync/fake_sync_service.dart';
import 'harness.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Sync on login flow (Android)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('sign-in pulls remote data and shows it on the dashboard', (tester) async {
      h = await AppHarness.create(
        tester,
        initiallyAnonymous: true,
        syncServiceFactory: (pactRepo, showupRepo) => _SeedingSyncService(pactRepo, showupRepo),
        extraOverrides: [
          // Pin the clock so the seeded showup is not auto-failed.
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
      );
      final strings = l10n(tester);

      // ── 1. Dashboard starts empty (anonymous user, no data yet) ─────────
      await waitFor(tester, find.text(strings.noPactsYet));
      expect(find.text('Morning Run'), findsNothing);

      // ── 2. Open sync status dialog ───────────────────────────────────────
      // Anonymous user → sync state = notLinked → cloud_off icon.
      // Wait for the icon to confirm the auth stream has propagated to
      // SyncStatusViewModel before tapping, so the dialog opens in the
      // correct notLinked state and shows "Sign in with Google".
      await waitFor(tester, find.byIcon(Icons.cloud_off_outlined));
      await tester.tap(find.byKey(const Key('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // ── 3. Tap "Sign in with Google" ────────────────────────────────────
      // The dialog action closes the dialog first (Navigator.pop) then fires
      // vm.linkWithGoogle() unawaited. linkWithGoogle():
      //   1. calls FakeAuthService.linkWithGoogle() → auth state → non-anonymous
      //   2. awaits _SeedingSyncService.pullRemoteChanges() → seeds repos
      //   3. invalidates hasActivePactsProvider and calls dashboard load()
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump(); // dialog pops + linkWithGoogle() starts

      // ── 4. Wait for dashboard to reload with remote data ─────────────────
      await waitFor(tester, find.text('Morning Run'));
      expect(find.text('Morning Run'), findsOneWidget);
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
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

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
