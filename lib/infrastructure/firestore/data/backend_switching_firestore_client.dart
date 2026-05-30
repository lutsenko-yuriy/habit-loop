import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Debug/profile-only [FirestoreClient] that reads the
/// `debug_firestore_backend` Remote Config key on **every** call and delegates
/// to either the real Firebase adapter or an in-memory [FakeFirestoreClient].
///
/// ## Backend modes (key `debug_firestore_backend`)
///
/// | Value | Behaviour |
/// |---|---|
/// | `'firebase'` (default) | Delegates to [firebase], the real adapter. |
/// | `'fake'` | Delegates to [fake], an in-memory [FakeFirestoreClient]. |
///
/// Switching via the in-app RC overrides screen takes effect immediately on
/// the next Firestore call without an app restart. The [fake] client starts
/// empty — write operations still succeed but data is held only in memory for
/// the current app session.
///
/// **Debug/profile only** — never construct this class in release builds.
class BackendSwitchingFirestoreClient implements FirestoreClient {
  BackendSwitchingFirestoreClient({
    required FirestoreClient firebase,
    required FakeFirestoreClient fake,
    required RemoteConfigService rc,
  })  : _firebase = firebase,
        _fake = fake,
        _rc = rc;

  final FirestoreClient _firebase;
  final FakeFirestoreClient _fake;
  final RemoteConfigService _rc;

  static const _keyBackend = 'debug_firestore_backend';

  /// Returns the active backend based on the current RC value.
  FirestoreClient get _active => _rc.getString(_keyBackend) == 'fake' ? _fake : _firebase;

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) => _active.getPacts(userId);

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) => _active.getShowups(userId);

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) =>
      _active.upsertPact(userId, pactId, data);

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) =>
      _active.upsertShowup(userId, showupId, data);

  @override
  Future<void> deletePact(String userId, String pactId) => _active.deletePact(userId, pactId);

  @override
  Future<void> deleteShowup(String userId, String showupId) => _active.deleteShowup(userId, showupId);
}
