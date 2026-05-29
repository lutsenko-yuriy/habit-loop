import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fault_injecting_firestore_client.dart';

import '../../remote_config/fake_remote_config_service.dart';

void main() {
  group('FaultInjectingFirestoreClient', () {
    late FakeFirestoreClient inner;

    setUp(() {
      inner = FakeFirestoreClient()
        ..seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Meditate'}
            }
          },
          showups: {
            'user-1': {
              's-1': <String, dynamic>{'status': 'pending'}
            }
          },
        ));
    });

    FaultInjectingFirestoreClient makePerfect([Random? random]) => FaultInjectingFirestoreClient(
          inner: inner,
          rc: FakeRemoteConfigService(),
          random: random,
        );

    FaultInjectingFirestoreClient makeAbsent() => FaultInjectingFirestoreClient(
          inner: inner,
          rc: FakeRemoteConfigService(overrides: {'debug_connectivity_state': 'absent'}),
        );

    FaultInjectingFirestoreClient makeUnstable(int stability, [Random? random]) => FaultInjectingFirestoreClient(
          inner: inner,
          rc: FakeRemoteConfigService(overrides: {
            'debug_connectivity_state': 'unstable',
            'debug_connectivity_stability_percent': stability,
          }),
          random: random,
        );

    // -------------------------------------------------------------------------
    // Perfect connectivity — delegates to inner
    // -------------------------------------------------------------------------

    group('perfect connectivity', () {
      test('getPacts delegates to inner and returns its results', () async {
        expect(await makePerfect().getPacts('user-1'), hasLength(1));
      });

      test('getShowups delegates to inner and returns its results', () async {
        expect(await makePerfect().getShowups('user-1'), hasLength(1));
      });

      test('upsertPact delegates to inner', () async {
        await makePerfect().upsertPact('user-1', 'pact-2', {'habit_name': 'Jog'});
        expect(await inner.getPacts('user-1'), hasLength(2));
      });

      test('upsertShowup delegates to inner', () async {
        await makePerfect().upsertShowup('user-1', 's-2', {'status': 'done'});
        expect(await inner.getShowups('user-1'), hasLength(2));
      });

      test('deletePact delegates to inner', () async {
        await makePerfect().deletePact('user-1', 'pact-1');
        expect(await inner.getPacts('user-1'), isEmpty);
      });

      test('deleteShowup delegates to inner', () async {
        await makePerfect().deleteShowup('user-1', 's-1');
        expect(await inner.getShowups('user-1'), isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Absent connectivity — always throws
    // -------------------------------------------------------------------------

    group('absent connectivity', () {
      test('getPacts throws', () {
        expect(makeAbsent().getPacts('user-1'), throwsException);
      });

      test('getShowups throws', () {
        expect(makeAbsent().getShowups('user-1'), throwsException);
      });

      test('upsertPact throws', () {
        expect(makeAbsent().upsertPact('user-1', 'pact-1', {}), throwsException);
      });

      test('upsertShowup throws', () {
        expect(makeAbsent().upsertShowup('user-1', 's-1', {}), throwsException);
      });

      test('deletePact throws', () {
        expect(makeAbsent().deletePact('user-1', 'pact-1'), throwsException);
      });

      test('deleteShowup throws', () {
        expect(makeAbsent().deleteShowup('user-1', 's-1'), throwsException);
      });
    });

    // -------------------------------------------------------------------------
    // Unstable connectivity — probabilistic
    // -------------------------------------------------------------------------

    group('unstable connectivity', () {
      test('stability=100 never throws (all succeed)', () async {
        final client = makeUnstable(100);
        for (var i = 0; i < 10; i++) {
          await client.getPacts('user-1'); // must not throw
        }
      });

      test('stability=0 always throws (all fail)', () {
        expect(makeUnstable(0).getPacts('user-1'), throwsException);
      });

      test('stability=50 with seeded Random produces both successes and failures', () async {
        final client = makeUnstable(50, Random(0));
        var successes = 0;
        var failures = 0;
        for (var i = 0; i < 20; i++) {
          try {
            await client.getPacts('user-1');
            successes++;
          } catch (_) {
            failures++;
          }
        }
        expect(successes, greaterThan(0), reason: 'some calls should succeed');
        expect(failures, greaterThan(0), reason: 'some calls should fail');
      });
    });

    // -------------------------------------------------------------------------
    // Dynamic — state is read on every call
    // -------------------------------------------------------------------------

    test('connectivity state change takes effect immediately on the next call', () async {
      final overrides = <String, dynamic>{'debug_connectivity_state': 'perfect'};
      final client = FaultInjectingFirestoreClient(
        inner: inner,
        rc: FakeRemoteConfigService(overrides: overrides),
      );

      // Perfect → succeeds
      await client.getPacts('user-1');

      // Switch to absent
      overrides['debug_connectivity_state'] = 'absent';

      // Next call throws immediately
      expect(client.getPacts('user-1'), throwsException);
    });

    // -------------------------------------------------------------------------
    // Default state — no RC override → behaves as perfect
    // -------------------------------------------------------------------------

    test('defaults to perfect behaviour when no state override is set', () async {
      // FakeRemoteConfigService falls back to RemoteConfigDefaults.all →
      // 'debug_connectivity_state' = 'perfect'
      final client = FaultInjectingFirestoreClient(inner: inner, rc: FakeRemoteConfigService());
      expect(await client.getPacts('user-1'), hasLength(1));
    });
  });
}
