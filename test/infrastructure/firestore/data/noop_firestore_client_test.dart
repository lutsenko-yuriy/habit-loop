import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/firestore/data/noop_firestore_client.dart';

void main() {
  group('NoopFirestoreClient', () {
    late NoopFirestoreClient client;

    setUp(() => client = NoopFirestoreClient());

    test('getPacts returns an empty list', () async {
      final result = await client.getPacts('user-1');
      expect(result, isEmpty);
    });

    test('getShowups returns an empty list', () async {
      final result = await client.getShowups('user-1');
      expect(result, isEmpty);
    });

    test('upsertPact completes without throwing', () async {
      await expectLater(
        client.upsertPact('user-1', 'pact-1', {'habit_name': 'Meditate'}),
        completes,
      );
    });

    test('upsertShowup completes without throwing', () async {
      await expectLater(
        client.upsertShowup('user-1', 'showup-1', {'status': 'pending'}),
        completes,
      );
    });

    test('deletePact completes without throwing', () async {
      await expectLater(client.deletePact('user-1', 'pact-1'), completes);
    });

    test('deleteShowup completes without throwing', () async {
      await expectLater(client.deleteShowup('user-1', 'showup-1'), completes);
    });
  });
}
