import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// No-op [RemoteConfigService] used as the default when Firebase is not wired in.
///
/// All getters read from [RemoteConfigDefaults.all] and return the in-code
/// default value. `initialize()` is a safe no-op. This ensures call sites can
/// always call `ref.read(remoteConfigServiceProvider).getInt(...)` without null
/// guards, and tests that do not care about Remote Config remain unaffected.
///
/// In debug and profile builds, each call is logged via [debugPrint] so
/// developers can verify which config values are being read.
final class NoopRemoteConfigService implements RemoteConfigService {
  @override
  Future<void> initialize() async {
    debugPrint('[RemoteConfig] initialize (noop)');
  }

  @override
  int getInt(String key) {
    debugPrint('[RemoteConfig] getInt($key) (noop)');
    final value = RemoteConfigDefaults.all[key];
    return value is int ? value : 0;
  }

  @override
  bool getBool(String key) {
    debugPrint('[RemoteConfig] getBool($key) (noop)');
    final value = RemoteConfigDefaults.all[key];
    return value is bool ? value : false;
  }

  @override
  String getString(String key) {
    debugPrint('[RemoteConfig] getString($key) (noop)');
    final value = RemoteConfigDefaults.all[key];
    return value is String ? value : '';
  }

  @override
  double getDouble(String key) {
    debugPrint('[RemoteConfig] getDouble($key) (noop)');
    final value = RemoteConfigDefaults.all[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}
