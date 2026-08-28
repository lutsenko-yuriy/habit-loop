import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';

/// Seed data for [FakeFirestoreClient].
///
/// [pacts] maps `userId → pactId → document fields`.
/// [showups] maps `userId → showupId → document fields`.
/// [pactBreaks] maps `userId → pactBreakId → document fields`.
/// [userProfiles] maps `userId → the single profile document's fields`
/// (there is no per-id key — one profile document per user).
class FakeFirestoreSeedData {
  const FakeFirestoreSeedData({
    this.pacts = const {},
    this.showups = const {},
    this.pactBreaks = const {},
    this.userProfiles = const {},
  });

  final Map<String, Map<String, Map<String, dynamic>>> pacts;
  final Map<String, Map<String, Map<String, dynamic>>> showups;
  final Map<String, Map<String, Map<String, dynamic>>> pactBreaks;
  final Map<String, Map<String, dynamic>> userProfiles;
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

  // userId → pactBreakId → document fields
  final Map<String, Map<String, Map<String, dynamic>>> _pactBreaks = {};

  // userId → single profile document fields
  final Map<String, Map<String, dynamic>> _userProfiles = {};

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
    for (final entry in data.pactBreaks.entries) {
      final bucket = _pactBreaks.putIfAbsent(entry.key, () => {});
      entry.value.forEach((id, doc) => bucket[id] = Map<String, dynamic>.from(doc));
    }
    for (final entry in data.userProfiles.entries) {
      _userProfiles[entry.key] = Map<String, dynamic>.from(entry.value);
    }
  }

  /// Removes all pacts, showups, pact breaks, and user profiles from in-memory storage.
  void clear() {
    _pacts.clear();
    _showups.clear();
    _pactBreaks.clear();
    _userProfiles.clear();
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
      pactBreaks: _pactBreaks.map(
        (uid, docs) => MapEntry(
          uid,
          docs.map((id, doc) => MapEntry(id, Map<String, dynamic>.from(doc))),
        ),
      ),
      userProfiles: _userProfiles.map((uid, doc) => MapEntry(uid, Map<String, dynamic>.from(doc))),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async =>
      (_pacts[userId] ?? {}).values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {
    _pacts.putIfAbsent(userId, () => {})[pactId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {
    _pacts[userId]?.remove(pactId);
  }

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async =>
      (_showups[userId] ?? {}).values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {
    _showups.putIfAbsent(userId, () => {})[showupId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> deleteShowup(String userId, String showupId) async {
    _showups[userId]?.remove(showupId);
  }

  @override
  Future<List<Map<String, dynamic>>> getPactBreaks(String userId) async =>
      (_pactBreaks[userId] ?? {}).values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<void> upsertPactBreak(String userId, String pactBreakId, Map<String, dynamic> data) async {
    _pactBreaks.putIfAbsent(userId, () => {})[pactBreakId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> deletePactBreak(String userId, String pactBreakId) async {
    _pactBreaks[userId]?.remove(pactBreakId);
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = _userProfiles[userId];
    return doc == null ? null : Map<String, dynamic>.from(doc);
  }

  @override
  Future<void> upsertUserProfile(String userId, Map<String, dynamic> data) async {
    _userProfiles[userId] = Map<String, dynamic>.from(data);
  }
}
