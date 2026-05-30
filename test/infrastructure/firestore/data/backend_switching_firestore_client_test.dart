import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/firestore/data/backend_switching_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';

import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('BackendSwitchingFirestoreClient', () {
    late FakeFirestoreClient firebaseStub; // stands in for the real Firebase adapter
    late FakeFirestoreClient fakeBackend;
    late FakeRemoteConfigService rc;

    const userId = 'user-1';
    const pactDoc = <String, dynamic>{'id': 'pact-1', 'habit_name': 'Run'};
    const showupDoc = <String, dynamic>{'id': 'showup-1', 'pact_id': 'pact-1'};

    setUp(() {
      firebaseStub = FakeFirestoreClient()
        ..seed(const FakeFirestoreSeedData(
          pacts: {
            userId: {'pact-1': pactDoc},
          },
          showups: {
            userId: {'showup-1': showupDoc},
          },
        ));
      fakeBackend = FakeFirestoreClient(); // starts empty
      rc = FakeRemoteConfigService();
    });

    BackendSwitchingFirestoreClient build() => BackendSwitchingFirestoreClient(
          firebase: firebaseStub,
          fake: fakeBackend,
          rc: rc,
        );

    test('defaults to firebase backend when RC key is absent', () async {
      // No override → getString returns the in-code default 'firebase'.
      final client = build();
      final pacts = await client.getPacts(userId);
      expect(pacts, hasLength(1));
      expect(pacts.first['habit_name'], 'Run');
    });

    test('delegates to firebase backend when RC key is "firebase"', () async {
      rc.overrides['debug_firestore_backend'] = 'firebase';
      final client = build();
      final pacts = await client.getPacts(userId);
      expect(pacts, hasLength(1));
    });

    test('delegates to fake backend when RC key is "fake"', () async {
      rc.overrides['debug_firestore_backend'] = 'fake';
      final client = build();
      // fakeBackend is empty — should return no pacts.
      final pacts = await client.getPacts(userId);
      expect(pacts, isEmpty);
    });

    test('switching RC key at runtime changes backend for subsequent calls', () async {
      final client = build();

      // Initially firebase.
      rc.overrides['debug_firestore_backend'] = 'firebase';
      expect(await client.getPacts(userId), hasLength(1));

      // Switch to fake.
      rc.overrides['debug_firestore_backend'] = 'fake';
      expect(await client.getPacts(userId), isEmpty);

      // Switch back to firebase.
      rc.overrides['debug_firestore_backend'] = 'firebase';
      expect(await client.getPacts(userId), hasLength(1));
    });

    test('getShowups delegates to firebase when RC key is "firebase"', () async {
      rc.overrides['debug_firestore_backend'] = 'firebase';
      final client = build();
      final showups = await client.getShowups(userId);
      expect(showups, hasLength(1));
      expect(showups.first['pact_id'], 'pact-1');
    });

    test('getShowups returns empty from fake backend', () async {
      rc.overrides['debug_firestore_backend'] = 'fake';
      final client = build();
      expect(await client.getShowups(userId), isEmpty);
    });

    test('upsertPact writes to fake backend when active', () async {
      rc.overrides['debug_firestore_backend'] = 'fake';
      final client = build();
      await client.upsertPact(userId, 'pact-new', {'id': 'pact-new'});
      final pacts = await client.getPacts(userId);
      expect(pacts, hasLength(1));
      expect(pacts.first['id'], 'pact-new');
    });

    test('upsertPact writes to firebase backend when active', () async {
      rc.overrides['debug_firestore_backend'] = 'firebase';
      final client = build();
      await client.upsertPact(userId, 'pact-new', {'id': 'pact-new'});
      final pacts = await client.getPacts(userId);
      expect(pacts, hasLength(2));
    });

    test('deletePact removes from active backend', () async {
      rc.overrides['debug_firestore_backend'] = 'firebase';
      final client = build();
      await client.deletePact(userId, 'pact-1');
      expect(await client.getPacts(userId), isEmpty);
    });

    test('deleteShowup removes from active backend', () async {
      rc.overrides['debug_firestore_backend'] = 'firebase';
      final client = build();
      await client.deleteShowup(userId, 'showup-1');
      expect(await client.getShowups(userId), isEmpty);
    });

    test('unrecognised RC value falls back to firebase', () async {
      rc.overrides['debug_firestore_backend'] = 'unknown_value';
      final client = build();
      // Should behave the same as 'firebase'.
      expect(await client.getPacts(userId), hasLength(1));
    });
  });
}
