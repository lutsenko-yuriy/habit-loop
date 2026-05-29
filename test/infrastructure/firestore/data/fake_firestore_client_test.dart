import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';

void main() {
  group('FakeFirestoreClient', () {
    late FakeFirestoreClient client;

    setUp(() => client = FakeFirestoreClient());

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('getPacts returns empty list when nothing seeded', () async {
      expect(await client.getPacts('user-1'), isEmpty);
    });

    test('getShowups returns empty list when nothing seeded', () async {
      expect(await client.getShowups('user-1'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // seed()
    // -------------------------------------------------------------------------

    group('seed', () {
      test('populates pacts for the seeded userId', () async {
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Meditate'}
            },
          },
        ));

        final pacts = await client.getPacts('user-1');
        expect(pacts, hasLength(1));
        expect(pacts.first['habit_name'], 'Meditate');
      });

      test('populates showups for the seeded userId', () async {
        client.seed(const FakeFirestoreSeedData(
          showups: {
            'user-1': {
              's-1': <String, dynamic>{'status': 'done'}
            },
          },
        ));

        final showups = await client.getShowups('user-1');
        expect(showups, hasLength(1));
        expect(showups.first['status'], 'done');
      });

      test('is additive — second seed merges new documents with existing ones', () async {
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Meditate'}
            }
          },
        ));
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-2': <String, dynamic>{'habit_name': 'Jog'}
            }
          },
        ));

        expect(await client.getPacts('user-1'), hasLength(2));
      });

      test('second seed overwrites on document-id collision', () async {
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Old'}
            }
          },
        ));
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'New'}
            }
          },
        ));

        final pacts = await client.getPacts('user-1');
        expect(pacts, hasLength(1));
        expect(pacts.first['habit_name'], 'New');
      });
    });

    // -------------------------------------------------------------------------
    // clear()
    // -------------------------------------------------------------------------

    test('clear removes all pacts and showups', () async {
      client.seed(const FakeFirestoreSeedData(
        pacts: {
          'user-1': {'pact-1': <String, dynamic>{}}
        },
        showups: {
          'user-1': {'s-1': <String, dynamic>{}}
        },
      ));

      client.clear();

      expect(await client.getPacts('user-1'), isEmpty);
      expect(await client.getShowups('user-1'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // snapshot()
    // -------------------------------------------------------------------------

    group('snapshot', () {
      test('reflects the current in-memory state', () {
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Meditate'}
            },
          },
        ));

        final snap = client.snapshot();
        expect(snap.pacts['user-1']?['pact-1']?['habit_name'], 'Meditate');
      });

      test('mutating the snapshot does not affect stored data', () async {
        client.seed(const FakeFirestoreSeedData(
          pacts: {
            'user-1': {
              'pact-1': <String, dynamic>{'habit_name': 'Original'}
            }
          },
        ));

        final snap = client.snapshot();
        snap.pacts['user-1']!['pact-1']!['habit_name'] = 'Mutated';

        final pacts = await client.getPacts('user-1');
        expect(pacts.first['habit_name'], 'Original');
      });

      test('reflects writes made after seeding', () async {
        await client.upsertPact('user-1', 'pact-1', {'habit_name': 'Yoga'});

        final snap = client.snapshot();
        expect(snap.pacts['user-1']?['pact-1']?['habit_name'], 'Yoga');
      });

      test('does not include deleted documents', () async {
        await client.upsertPact('user-1', 'pact-1', {'habit_name': 'A'});
        await client.deletePact('user-1', 'pact-1');

        expect(client.snapshot().pacts['user-1'] ?? {}, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // User isolation
    // -------------------------------------------------------------------------

    test('getPacts returns only documents for the requested userId', () async {
      client.seed(const FakeFirestoreSeedData(
        pacts: {
          'user-1': {
            'pact-1': <String, dynamic>{'habit_name': 'A'}
          },
          'user-2': {
            'pact-2': <String, dynamic>{'habit_name': 'B'}
          },
        },
      ));

      final user1Pacts = await client.getPacts('user-1');
      expect(user1Pacts, hasLength(1));
      expect(user1Pacts.first['habit_name'], 'A');
    });

    test('getShowups returns only documents for the requested userId', () async {
      client.seed(const FakeFirestoreSeedData(
        showups: {
          'user-1': {
            's-1': <String, dynamic>{'status': 'done'}
          },
          'user-2': {
            's-2': <String, dynamic>{'status': 'failed'}
          },
        },
      ));

      expect(await client.getShowups('user-1'), hasLength(1));
      expect(await client.getShowups('user-2'), hasLength(1));
    });

    // -------------------------------------------------------------------------
    // upsertPact / upsertShowup
    // -------------------------------------------------------------------------

    test('upsertPact adds a new document', () async {
      await client.upsertPact('user-1', 'pact-1', {'habit_name': 'Meditate'});

      final pacts = await client.getPacts('user-1');
      expect(pacts, hasLength(1));
      expect(pacts.first['habit_name'], 'Meditate');
    });

    test('upsertPact overwrites an existing document with the same id', () async {
      await client.upsertPact('user-1', 'pact-1', {'habit_name': 'Old'});
      await client.upsertPact('user-1', 'pact-1', {'habit_name': 'New'});

      final pacts = await client.getPacts('user-1');
      expect(pacts, hasLength(1));
      expect(pacts.first['habit_name'], 'New');
    });

    test('upsertShowup adds a new document', () async {
      await client.upsertShowup('user-1', 's-1', {'status': 'pending'});

      expect(await client.getShowups('user-1'), hasLength(1));
    });

    test('upsertShowup overwrites an existing document with the same id', () async {
      await client.upsertShowup('user-1', 's-1', {'status': 'pending'});
      await client.upsertShowup('user-1', 's-1', {'status': 'done'});

      final showups = await client.getShowups('user-1');
      expect(showups, hasLength(1));
      expect(showups.first['status'], 'done');
    });

    // -------------------------------------------------------------------------
    // deletePact / deleteShowup
    // -------------------------------------------------------------------------

    test('deletePact removes the document', () async {
      await client.upsertPact('user-1', 'pact-1', {'habit_name': 'A'});
      await client.deletePact('user-1', 'pact-1');

      expect(await client.getPacts('user-1'), isEmpty);
    });

    test('deletePact is a no-op when document does not exist', () async {
      await expectLater(client.deletePact('user-1', 'nonexistent'), completes);
    });

    test('deletePact does not affect other documents for the same user', () async {
      await client.upsertPact('user-1', 'pact-1', {});
      await client.upsertPact('user-1', 'pact-2', {});
      await client.deletePact('user-1', 'pact-1');

      expect(await client.getPacts('user-1'), hasLength(1));
    });

    test('deleteShowup removes the document', () async {
      await client.upsertShowup('user-1', 's-1', {'status': 'done'});
      await client.deleteShowup('user-1', 's-1');

      expect(await client.getShowups('user-1'), isEmpty);
    });

    test('deleteShowup is a no-op when document does not exist', () async {
      await expectLater(client.deleteShowup('user-1', 'nonexistent'), completes);
    });

    // -------------------------------------------------------------------------
    // Defensive copies — getPacts / getShowups return copies
    // -------------------------------------------------------------------------

    test('getPacts returns copies — mutating the list does not affect stored data', () async {
      await client.upsertPact('user-1', 'pact-1', {'habit_name': 'A'});

      final result = await client.getPacts('user-1');
      result.first['habit_name'] = 'Mutated';

      final result2 = await client.getPacts('user-1');
      expect(result2.first['habit_name'], 'A');
    });

    test('getShowups returns copies — mutating the list does not affect stored data', () async {
      await client.upsertShowup('user-1', 's-1', {'status': 'pending'});

      final result = await client.getShowups('user-1');
      result.first['status'] = 'mutated';

      final result2 = await client.getShowups('user-1');
      expect(result2.first['status'], 'pending');
    });

    // -------------------------------------------------------------------------
    // No-throw contract
    // -------------------------------------------------------------------------

    test('all operations complete without throwing', () async {
      await expectLater(client.getPacts('nobody'), completes);
      await expectLater(client.getShowups('nobody'), completes);
      await expectLater(client.upsertPact('u', 'p', {}), completes);
      await expectLater(client.upsertShowup('u', 's', {}), completes);
      await expectLater(client.deletePact('u', 'nonexistent'), completes);
      await expectLater(client.deleteShowup('u', 'nonexistent'), completes);
    });
  });
}
