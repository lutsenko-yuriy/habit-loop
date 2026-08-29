import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';

/// Production [FirestoreClient] backed by the `cloud_firestore` SDK.
///
/// Only instantiated in `main.dart`. All methods have a no-throw contract —
/// exceptions from the SDK are swallowed so a Firestore outage can never
/// crash the app.
final class FirebaseFirestoreClientAdapter implements FirestoreClient {
  FirebaseFirestoreClientAdapter(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _pacts(String userId) =>
      _firestore.collection('users').doc(userId).collection('pacts');

  CollectionReference<Map<String, dynamic>> _showups(String userId) =>
      _firestore.collection('users').doc(userId).collection('showups');

  CollectionReference<Map<String, dynamic>> _pactBreaks(String userId) =>
      _firestore.collection('users').doc(userId).collection('pact_breaks');

  DocumentReference<Map<String, dynamic>> _userProfile(String userId) =>
      _firestore.collection('users').doc(userId).collection('profile').doc('main');

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async {
    try {
      final snapshot = await _pacts(userId).get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> upsertPact(
    String userId,
    String pactId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _pacts(userId).doc(pactId).set(data);
    } catch (_) {}
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {
    try {
      await _pacts(userId).doc(pactId).delete();
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async {
    try {
      final snapshot = await _showups(userId).get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> upsertShowup(
    String userId,
    String showupId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _showups(userId).doc(showupId).set(data);
    } catch (_) {}
  }

  @override
  Future<void> deleteShowup(String userId, String showupId) async {
    try {
      await _showups(userId).doc(showupId).delete();
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getPactBreaks(String userId) async {
    try {
      final snapshot = await _pactBreaks(userId).get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> upsertPactBreak(
    String userId,
    String pactBreakId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _pactBreaks(userId).doc(pactBreakId).set(data);
    } catch (_) {}
  }

  @override
  Future<void> deletePactBreak(String userId, String pactBreakId) async {
    try {
      await _pactBreaks(userId).doc(pactBreakId).delete();
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final snapshot = await _userProfile(userId).get();
      return snapshot.data();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _userProfile(userId).set(data);
    } catch (_) {}
  }
}
