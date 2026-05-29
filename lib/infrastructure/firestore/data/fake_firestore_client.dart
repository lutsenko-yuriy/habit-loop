import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';

/// Seed data for [FakeFirestoreClient].
///
/// [pacts] maps `userId → pactId → document fields`.
/// [showups] maps `userId → showupId → document fields`.
class FakeFirestoreSeedData {
  const FakeFirestoreSeedData({
    this.pacts = const {},
    this.showups = const {},
  });

  final Map<String, Map<String, Map<String, dynamic>>> pacts;
  final Map<String, Map<String, Map<String, dynamic>>> showups;
}

/// In-memory [FirestoreClient] for debug and profile builds.
///
/// Stores documents in `Map<userId, Map<id, data>>` maps for pacts and showups,
/// mirroring the flat Firestore layout without requiring a live Firebase project.
/// This lets QA exercise the pull/merge path end-to-end against deterministic
/// remote data.
///
/// Use [seed] to pre-populate initial state, [clear] to reset between test
/// scenarios, and [snapshot] to inspect the current in-memory state.
///
/// All read operations return defensive copies so that callers cannot mutate
/// the stored documents. [seed] also copies all incoming documents for the same
/// reason.
///
/// **Debug/profile only** — never construct this class in release builds.
class FakeFirestoreClient implements FirestoreClient {
  // userId → pactId → document fields
  final Map<String, Map<String, Map<String, dynamic>>> _pacts = {};

  // userId → showupId → document fields
  final Map<String, Map<String, Map<String, dynamic>>> _showups = {};

  /// Pre-populates the client with [data].
  ///
  /// Additive: calling [seed] multiple times merges all datasets. When two
  /// calls provide the same document id for the same user, the later call wins.
  void seed(FakeFirestoreSeedData data) {
    for (final entry in data.pacts.entries) {
      final bucket = _pacts.putIfAbsent(entry.key, () => {});
      entry.value.forEach((id, doc) => bucket[id] = Map<String, dynamic>.from(doc));
    }
    for (final entry in data.showups.entries) {
      final bucket = _showups.putIfAbsent(entry.key, () => {});
      entry.value.forEach((id, doc) => bucket[id] = Map<String, dynamic>.from(doc));
    }
  }

  /// Removes all pacts and showups from in-memory storage.
  void clear() {
    _pacts.clear();
    _showups.clear();
  }

  /// Returns a deep snapshot of the current in-memory state.
  ///
  /// Mutating the returned [FakeFirestoreSeedData] does not affect the stored
  /// documents.
  FakeFirestoreSeedData snapshot() {
    return FakeFirestoreSeedData(
      pacts: _pacts.map(
        (uid, docs) => MapEntry(
          uid,
          docs.map((id, doc) => MapEntry(id, Map<String, dynamic>.from(doc))),
        ),
      ),
      showups: _showups.map(
        (uid, docs) => MapEntry(
          uid,
          docs.map((id, doc) => MapEntry(id, Map<String, dynamic>.from(doc))),
        ),
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async =>
      (_pacts[userId] ?? {}).values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async =>
      (_showups[userId] ?? {}).values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {
    _pacts.putIfAbsent(userId, () => {})[pactId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {
    _showups.putIfAbsent(userId, () => {})[showupId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {
    _pacts[userId]?.remove(pactId);
  }

  @override
  Future<void> deleteShowup(String userId, String showupId) async {
    _showups[userId]?.remove(showupId);
  }
}
