import 'package:habit_loop/remote_config/domain/remote_config_defaults.dart';
import 'package:habit_loop/remote_config/domain/remote_config_service.dart';

/// A fake [RemoteConfigService] backed by an in-memory map.
///
/// Tests can inject specific flag values via the [overrides] map.
/// Getters look up [overrides] first, then fall back to [RemoteConfigDefaults.all].
class FakeRemoteConfigService implements RemoteConfigService {
  FakeRemoteConfigService({Map<String, dynamic>? overrides}) : overrides = overrides ?? {};

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
