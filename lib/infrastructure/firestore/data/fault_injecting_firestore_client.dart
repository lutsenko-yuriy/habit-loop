import 'dart:math';

import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Debug/profile-only [FirestoreClient] decorator that injects configurable
/// connectivity failures so QA can verify circuit-breaker transitions, retries,
/// and partial-failure handling without touching a live Firestore project.
///
/// The connectivity mode is read from [RemoteConfigService] on **every** call,
/// so the in-app Remote Config overrides screen can change the mode at runtime
/// without restarting the app.
///
/// ## Connectivity modes (key `debug_connectivity_state`)
///
/// | Value | Behaviour |
/// |---|---|
/// | `'perfect'` (default) | All calls delegate to [inner] unchanged. |
/// | `'absent'` | Every call throws — simulates no network / Firestore unreachable. |
/// | `'unstable'` | Each call succeeds with probability `debug_connectivity_stability_percent` / 100. |
///
/// ## Stability (key `debug_connectivity_stability_percent`)
///
/// Integer 0–100. Only meaningful when state is `'unstable'`.
/// `100` = all succeed, `0` = all fail, `50` ≈ half succeed.
/// Defaults to `100` (same as `'perfect'`).
///
/// **Debug/profile only** — never construct this class in release builds.
class FaultInjectingFirestoreClient implements FirestoreClient {
  FaultInjectingFirestoreClient({
    required FirestoreClient inner,
    required RemoteConfigService rc,
    Random? random,
  })  : _inner = inner,
        _rc = rc,
        _random = random ?? Random();

  final FirestoreClient _inner;
  final RemoteConfigService _rc;
  final Random _random;

  static const _keyState = 'debug_connectivity_state';
  static const _keyStability = 'debug_connectivity_stability_percent';

  /// Checks the current connectivity state and throws if the simulated
  /// connection is unavailable. Called before every delegated operation.
  void _maybeFail() {
    final state = _rc.getString(_keyState);
    switch (state) {
      case 'absent':
        throw Exception('FaultInjectingFirestoreClient: simulated connection absent');
      case 'unstable':
        final stability = _rc.getInt(_keyStability).clamp(0, 100);
        if (_random.nextInt(100) >= stability) {
          throw Exception('FaultInjectingFirestoreClient: simulated unstable connection failure');
        }
      default:
        // 'perfect' or any unrecognised value → pass through unchanged
        break;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPacts(String userId) async {
    _maybeFail();
    return _inner.getPacts(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getShowups(String userId) async {
    _maybeFail();
    return _inner.getShowups(userId);
  }

  @override
  Future<void> upsertPact(String userId, String pactId, Map<String, dynamic> data) async {
    _maybeFail();
    return _inner.upsertPact(userId, pactId, data);
  }

  @override
  Future<void> upsertShowup(String userId, String showupId, Map<String, dynamic> data) async {
    _maybeFail();
    return _inner.upsertShowup(userId, showupId, data);
  }

  @override
  Future<void> deletePact(String userId, String pactId) async {
    _maybeFail();
    return _inner.deletePact(userId, pactId);
  }

  @override
  Future<void> deleteShowup(String userId, String showupId) async {
    _maybeFail();
    return _inner.deleteShowup(userId, showupId);
  }
}
