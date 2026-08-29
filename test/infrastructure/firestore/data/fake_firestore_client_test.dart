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

    test('getPactBreaks returns empty list when nothing seeded', () async {
      expect(await client.getPactBreaks('user-1'), isEmpty);
    });

    test('getUserProfile returns null when nothing upserted', () async {
      expect(await client.getUserProfile('user-1'), isNull);
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

      test('populates pact breaks for the seeded userId', () async {
        client.seed(const FakeFirestoreSeedData(
          pactBreaks: {
            'user-1': {
              'break-1': <String, dynamic>{'rationale': 'Recovering from a cold'}
            },
          },
        ));

        final pactBreaks = await client.getPactBreaks('user-1');
        expect(pactBreaks, hasLength(1));
        expect(pactBreaks.first['rationale'], 'Recovering from a cold');
      });

      test('populates the user profile for the seeded userId', () async {
        client.seed(const FakeFirestoreSeedData(
          userProfiles: {
            'user-1': <String, dynamic>{'display_name': 'Jamie'},
          },
        ));

        final profile = await client.getUserProfile('user-1');
        expect(profile?['display_name'], 'Jamie');
      });

      test('second seed overwrites the user profile on collision (single doc per user)', () async {
        client.seed(const FakeFirestoreSeedData(
          userProfiles: {
            'user-1': <String, dynamic>{'display_name': 'Old'},
          },
        ));
        client.seed(const FakeFirestoreSeedData(
          userProfiles: {
            'user-1': <String, dynamic>{'display_name': 'New'},
          },
        ));

        expect((await client.getUserProfile('user-1'))?['display_name'], 'New');
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

    test('clear removes all pacts, showups, pact breaks, and user profiles', () async {
      client.seed(const FakeFirestoreSeedData(
        pacts: {
          'user-1': {'pact-1': <String, dynamic>{}}
        },
        showups: {
          'user-1': {'s-1': <String, dynamic>{}}
        },
        pactBreaks: {
          'user-1': {'break-1': <String, dynamic>{}}
        },
      ));
      await client.upsertUserProfile('user-1', {'display_name': 'Jamie'});

      client.clear();

      expect(await client.getPacts('user-1'), isEmpty);
      expect(await client.getShowups('user-1'), isEmpty);
      expect(await client.getPactBreaks('user-1'), isEmpty);
      expect(await client.getUserProfile('user-1'), isNull);
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

      test('reflects a seeded user profile', () async {
        client.seed(const FakeFirestoreSeedData(
          userProfiles: {
            'user-1': <String, dynamic>{'display_name': 'Jamie'},
          },
        ));

        expect(client.snapshot().userProfiles['user-1']?['display_name'], 'Jamie');
      });

      test('reflects a user profile written after seeding', () async {
        await client.upsertUserProfile('user-1', {'display_name': 'Written'});

        expect(client.snapshot().userProfiles['user-1']?['display_name'], 'Written');
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
    // upsertPactBreak / deletePactBreak
    // -------------------------------------------------------------------------

    test('upsertPactBreak adds a new document', () async {
      await client.upsertPactBreak('user-1', 'break-1', {'rationale': 'Travel'});

      final pactBreaks = await client.getPactBreaks('user-1');
      expect(pactBreaks, hasLength(1));
      expect(pactBreaks.first['rationale'], 'Travel');
    });

    test('upsertPactBreak overwrites an existing document with the same id', () async {
      await client.upsertPactBreak('user-1', 'break-1', {'rationale': 'Old'});
      await client.upsertPactBreak('user-1', 'break-1', {'rationale': 'New'});

      final pactBreaks = await client.getPactBreaks('user-1');
      expect(pactBreaks, hasLength(1));
      expect(pactBreaks.first['rationale'], 'New');
    });

    test('deletePactBreak removes the document', () async {
      await client.upsertPactBreak('user-1', 'break-1', {'rationale': 'A'});
      await client.deletePactBreak('user-1', 'break-1');

      expect(await client.getPactBreaks('user-1'), isEmpty);
    });

    test('deletePactBreak is a no-op when document does not exist', () async {
      await expectLater(client.deletePactBreak('user-1', 'nonexistent'), completes);
    });

    // -------------------------------------------------------------------------
    // getUserProfile / upsertUserProfile
    // -------------------------------------------------------------------------

    test('upsertUserProfile then getUserProfile returns the stored document', () async {
      await client.upsertUserProfile('user-1', {'display_name': 'Jamie'});

      expect((await client.getUserProfile('user-1'))?['display_name'], 'Jamie');
    });

    test('upsertUserProfile overwrites the previous document (singleton — no id)', () async {
      await client.upsertUserProfile('user-1', {'display_name': 'Old'});
      await client.upsertUserProfile('user-1', {'display_name': 'New'});

      expect((await client.getUserProfile('user-1'))?['display_name'], 'New');
    });

    test('getUserProfile is isolated per userId', () async {
      await client.upsertUserProfile('user-1', {'display_name': 'A'});
      await client.upsertUserProfile('user-2', {'display_name': 'B'});

      expect((await client.getUserProfile('user-1'))?['display_name'], 'A');
      expect((await client.getUserProfile('user-2'))?['display_name'], 'B');
    });

    test('getUserProfile returns a copy — mutating it does not affect stored data', () async {
      await client.upsertUserProfile('user-1', {'display_name': 'A'});

      final result = await client.getUserProfile('user-1');
      result!['display_name'] = 'Mutated';

      expect((await client.getUserProfile('user-1'))?['display_name'], 'A');
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
      await expectLater(client.getPactBreaks('nobody'), completes);
      await expectLater(client.upsertPact('u', 'p', {}), completes);
      await expectLater(client.upsertShowup('u', 's', {}), completes);
      await expectLater(client.upsertPactBreak('u', 'b', {}), completes);
      await expectLater(client.deletePact('u', 'nonexistent'), completes);
      await expectLater(client.deleteShowup('u', 'nonexistent'), completes);
      await expectLater(client.deletePactBreak('u', 'nonexistent'), completes);
      await expectLater(client.getUserProfile('nobody'), completes);
      await expectLater(client.upsertUserProfile('u', {}), completes);
    });
  });
}
