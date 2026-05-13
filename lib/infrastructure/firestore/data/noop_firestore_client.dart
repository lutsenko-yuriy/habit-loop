import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';

/// No-op [FirestoreClient] used in unit tests and as the default provider
/// before the production adapter is wired in `main.dart`.
///
/// All write operations are silent no-ops. All read operations return empty
/// lists so callers see "no remote data" rather than throwing.
class NoopFirestoreClient implements FirestoreClient {
  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async => [];

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {}

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {}

  @override
  Future<void> deletePact(String userId, String pactId) async {}

  @override
  Future<void> deleteShowup(String userId, String showupId) async {}
}
