import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

import 'test_remote_config_defaults.dart';

/// A fake [RemoteConfigService] backed by an in-memory map.
///
/// Tests can inject specific flag values via the [overrides] map.
/// Getters look up [overrides] first, then fall back to [RemoteConfigDefaults.all].
class FakeRemoteConfigService implements RemoteConfigService {
  FakeRemoteConfigService({Map<String, dynamic>? overrides}) : overrides = overrides ?? {};

  /// Layers [overrides] on top of [TestRemoteConfigDefaults.all], which is
  /// itself layered on top of [RemoteConfigDefaults.all]. Use this for any
  /// harness/test construction — the bare constructor is reserved for
  /// asserting production defaults (HAB-260).
  ///
  /// A `null`-valued entry in [overrides] is dropped rather than merged, so it
  /// can't shadow a test default and fall through to the production default —
  /// the getters' `overrides[key] ?? RemoteConfigDefaults.all[key]` lookup
  /// can't otherwise tell "absent key" from "present but null".
  FakeRemoteConfigService.withTestDefaults({Map<String, dynamic>? overrides})
      : overrides = {
          ...TestRemoteConfigDefaults.all,
          for (final entry in (overrides ?? const {}).entries)
            if (entry.value != null) entry.key: entry.value,
        };

  final Map<String, dynamic> overrides;

  @override
  Future<void> initialize() async {}

  @override
  int getInt(String key) {
    final value = overrides[key] ?? RemoteConfigDefaults.all[key];
    if (value is int) return value;
    return 0;
  }

  @override
  bool getBool(String key) {
    final value = overrides[key] ?? RemoteConfigDefaults.all[key];
    if (value is bool) return value;
    return false;
  }

  @override
  String getString(String key) {
    final value = overrides[key] ?? RemoteConfigDefaults.all[key];
    if (value is String) return value;
    return '';
  }

  @override
  double getDouble(String key) {
    final value = overrides[key] ?? RemoteConfigDefaults.all[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}
