/// Abstract interface for the Firestore remote storage layer.
///
/// Implementations must have a no-throw contract: all exceptions from the
/// underlying SDK must be caught internally so a Firestore outage can never
/// crash the app. Callers are responsible for checking success via return
/// values or separate retry logic (WU4).
///
/// The flat schema mirrors the local SQLite structure:
///   /users/{userId}/pacts/{pactId}
///   /users/{userId}/showups/{showupId}
///
/// All data is passed as plain [Map<String, dynamic>] so this interface has
/// no dependency on the `cloud_firestore` SDK — test fakes can implement it
/// without importing Firebase.
abstract class FirestoreClient {
  /// Returns all pact documents for [userId] as raw field maps.
  Future<List<Map<String, dynamic>>> getPacts(String userId);

  /// Returns all showup documents for [userId] as raw field maps.
  Future<List<Map<String, dynamic>>> getShowups(String userId);

  /// Writes (creates or overwrites) the pact document at
  /// `/users/[userId]/pacts/[pactId]` with [data].
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data);

  /// Writes (creates or overwrites) the showup document at
  /// `/users/[userId]/showups/[showupId]` with [data].
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data);

  /// Deletes the pact document at `/users/[userId]/pacts/[pactId]`.
  Future<void> deletePact(String userId, String pactId);

  /// Deletes the showup document at `/users/[userId]/showups/[showupId]`.
  Future<void> deleteShowup(String userId, String showupId);
}
