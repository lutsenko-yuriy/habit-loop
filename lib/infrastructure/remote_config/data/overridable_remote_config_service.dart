import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// A [RemoteConfigService] that checks a [RemoteConfigOverrideStore] before
/// delegating to an inner service.
///
/// Used in debug and profile builds to allow manual override of any Remote
/// Config key for local testing of A/B experiments and feature flags. In
/// release builds the inner service is used directly (no wrapping).
///
/// Override values are stored as strings and parsed to the expected type at
/// read time. If parsing fails (e.g. a non-numeric string for [getInt]), the
/// call falls back to the inner service.
///
/// **Debug and profile builds only.** Do not wire in release builds.
final class OverridableRemoteConfigService implements RemoteConfigService {
  final RemoteConfigService _inner;
  final RemoteConfigOverrideStore _store;

  const OverridableRemoteConfigService({
    required RemoteConfigService inner,
    required RemoteConfigOverrideStore store,
  })  : _inner = inner,
        _store = store;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  int getInt(String key) {
    final raw = _store.getOverride(key);
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return _inner.getInt(key);
  }

  @override
  bool getBool(String key) {
    final raw = _store.getOverride(key);
    if (raw != null) {
      if (raw == 'true') return true;
      if (raw == 'false') return false;
    }
    return _inner.getBool(key);
  }

  @override
  String getString(String key) {
    final raw = _store.getOverride(key);
    if (raw != null) return raw;
    return _inner.getString(key);
  }

  @override
  double getDouble(String key) {
    final raw = _store.getOverride(key);
    if (raw != null) {
      final parsed = double.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return _inner.getDouble(key);
  }
}
