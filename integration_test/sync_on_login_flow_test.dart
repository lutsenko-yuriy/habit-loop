// End-to-end flow: app starts → anonymous user → signs in with Google →
// remote data is pulled → pact appears on dashboard.
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

// Fixed clock placed 5 minutes before the showup window so the auto-fail
// check (now > scheduledAt + duration) never triggers during the test.
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
      // vm.linkWithGoogle() unawaited. After pumping, linkWithGoogle():
      //   1. calls FakeAuthService.linkWithGoogle() → auth state → non-anonymous
      //   2. calls _SeedingSyncService.pullRemoteChanges() → seeds repos
      //   3. invalidates hasActivePactsProvider and calls dashboard load()
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump(); // dialog pops + linkWithGoogle() starts

      // ── 4. Wait for dashboard to reload with remote data ─────────────────
      await waitFor(tester, find.text('Morning Run'));
      expect(find.text('Morning Run'), findsOneWidget);
    });
  });
}
