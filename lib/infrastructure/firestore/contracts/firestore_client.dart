/// Abstract interface for the Firestore remote storage layer.
///
/// Implementations must have a no-throw contract: all exceptions from the
/// underlying SDK must be caught internally so a Firestore outage can never
/// crash the app. Write methods return void; callers use separate retry logic
/// (WU4) to verify eventual consistency.
///
/// The flat schema mirrors the local SQLite structure:
///   /users/{userId}/pacts/{pactId}
///   /users/{userId}/showups/{showupId}
///   /users/{userId}/pact_breaks/{pactBreakId}
///   /users/{userId}/profile/main
///
/// All data is passed as plain [Map<String, dynamic>] so this interface has
/// no dependency on the `cloud_firestore` SDK — test fakes can implement it
/// without importing Firebase.
abstract class FirestoreClient {
  /// Returns all pact documents for [userId] as raw field maps.
  Future<List<Map<String, dynamic>>> getPacts(String userId);

  /// Writes (creates or overwrites) the pact document at
  /// `/users/[userId]/pacts/[pactId]` with [data].
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data);

  /// Deletes the pact document at `/users/[userId]/pacts/[pactId]`.
  Future<void> deletePact(String userId, String pactId);

  /// Returns all showup documents for [userId] as raw field maps.
  Future<List<Map<String, dynamic>>> getShowups(String userId);

  /// Writes (creates or overwrites) the showup document at
  /// `/users/[userId]/showups/[showupId]` with [data].
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data);

  /// Deletes the showup document at `/users/[userId]/showups/[showupId]`.
  Future<void> deleteShowup(String userId, String showupId);

  /// Returns all pact-break documents for [userId] as raw field maps.
  Future<List<Map<String, dynamic>>> getPactBreaks(String userId);

  /// Writes (creates or overwrites) the pact-break document at
  /// `/users/[userId]/pact_breaks/[pactBreakId]` with [data].
  Future<void> upsertPactBreak(String userId, String pactBreakId, Map<String, dynamic> data);

  /// Deletes the pact-break document at `/users/[userId]/pact_breaks/[pactBreakId]`.
  Future<void> deletePactBreak(String userId, String pactBreakId);

  /// Returns the single user-profile document for [userId] at
  /// `/users/[userId]/profile/main`, or `null` if it does not exist.
  Future<Map<String, dynamic>?> getUserProfile(String userId);

  /// Writes (creates or overwrites) the user-profile document at
  /// `/users/[userId]/profile/main` with [data].
  Future<void> upsertUserProfile(String userId, Map<String, dynamic> data);
}
