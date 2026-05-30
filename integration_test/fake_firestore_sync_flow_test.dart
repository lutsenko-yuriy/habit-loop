// Integration tests for AppHarness fake-Firestore mode (HAB-90 WU5).
//
// These tests use a [FakeFirestoreClient] as the Firestore backend — no live
// Firebase project needed. AppHarness wires the real [FirestoreSyncService]
// against the provided client so the full sync stack (pullRemoteChanges,
// circuit-breaker) is exercised end-to-end.
//
// Run with: flutter test integration_test/fake_firestore_sync_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fault_injecting_firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Pin the clock to 07:55 on 2099-07-01 so the 08:00 showup is not auto-failed.
final _testNow = DateTime(2099, 7, 1, 7, 55);

/// Remote pact seeded into the FakeFirestoreClient under 'test-user'.
const _pactId = 'remote-pact-1';
final _remotePact = Pact(
  id: _pactId,
  habitName: 'Remote Meditation',
  startDate: DateTime(2099, 7, 1),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 15),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: DateTime(2099, 7, 1),
);

/// Showup for the remote pact.
const _showupId = 'remote-showup-1';
final _remoteShowup = Showup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 7, 1, 8, 0),
  duration: const Duration(minutes: 15),
  status: ShowupStatus.pending,
);

/// Disable onboarding auto-advance so the carousel doesn't flicker mid-test.
final _noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('FakeFirestoreClient integration', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('pullRemoteChanges merges FakeFirestoreClient data onto dashboard after sign-in', (tester) async {
      final updatedAt = DateTime(2099, 7, 1);
      final fakeFirestore = FakeFirestoreClient()
        ..seed(FakeFirestoreSeedData(
          pacts: {
            'test-user': {_pactId: SyncMapper.pactToDocument(_remotePact, updatedAt: updatedAt)},
          },
          showups: {
            'test-user': {_showupId: SyncMapper.showupToDocument(_remoteShowup, updatedAt: updatedAt)},
          },
        ));

      h = await AppHarness.create(
        tester,
        firestoreClient: fakeFirestore,
        initiallyAnonymous: true,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
          _noAutoAdvance,
        ],
      );
      final strings = l10n(tester);

      // Anonymous user sees onboarding carousel — no remote data yet.
      await waitFor(tester, find.text(strings.onboardingSlide0Title));
      expect(find.text('Remote Meditation'), findsNothing);

      // Sign in → linkWithGoogle() → pullRemoteChanges() uses the real
      // FirestoreSyncService which fetches from FakeFirestoreClient, merges
      // the pact into InMemoryPactRepository, then reloads the dashboard.
      await waitFor(tester, find.text(strings.signInWithGoogle));
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump();

      await waitFor(tester, find.text('Remote Meditation'));
      expect(find.text('Remote Meditation'), findsOneWidget);
    });

    testWidgets('FaultInjectingFirestoreClient in absent mode: remote data does not appear', (tester) async {
      final fakeFirestore = FakeFirestoreClient()
        ..seed(FakeFirestoreSeedData(
          pacts: {
            'test-user': {
              _pactId: SyncMapper.pactToDocument(_remotePact, updatedAt: DateTime(2099, 7, 1)),
            },
          },
        ));

      // Wrap in FaultInjectingFirestoreClient with connectivity absent → every
      // call throws, so pullRemoteChanges() will record a CB failure and the
      // remote pact will never be merged.
      final faultClient = FaultInjectingFirestoreClient(
        inner: fakeFirestore,
        rc: FakeRemoteConfigService(overrides: {'debug_connectivity_state': 'absent'}),
      );

      h = await AppHarness.create(
        tester,
        firestoreClient: faultClient,
        initiallyAnonymous: true,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
          _noAutoAdvance,
        ],
      );
      final strings = l10n(tester);

      await waitFor(tester, find.text(strings.onboardingSlide0Title));

      // Sign in — pullRemoteChanges() throws due to absent connectivity.
      // The circuit breaker records the failure; no remote data is merged.
      await waitFor(tester, find.text(strings.signInWithGoogle));
      await tester.tap(find.text(strings.signInWithGoogle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Remote pact must not appear on the dashboard.
      expect(find.text('Remote Meditation'), findsNothing);
    });
  });
}
