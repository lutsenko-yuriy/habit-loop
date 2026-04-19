import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:habit_loop/remote_config/domain/remote_config_defaults.dart';
import 'package:habit_loop/remote_config/domain/remote_config_service.dart';

/// Thin abstraction over the Firebase Remote Config SDK methods used by this app.
///
/// Exists so tests can inject a fake without depending on the real Firebase SDK.
abstract interface class FirebaseRemoteConfigClient {
  /// Applies [RemoteConfigSettings] such as fetch timeout and minimum fetch interval.
  Future<void> setConfigSettings(RemoteConfigSettings settings);

  /// Registers in-code default values that are used before a successful fetch.
  Future<void> setDefaults(Map<String, dynamic> defaults);

  /// Fetches and activates the latest Remote Config values.
  ///
  /// Returns `true` if new values were activated.
  Future<bool> fetchAndActivate();

  /// Returns the [RemoteConfigValue] for the given [key].
  RemoteConfigValue getValue(String key);
}

/// [RemoteConfigService] implementation backed by Firebase Remote Config.
///
/// All failures are swallowed so a Remote Config outage never crashes the app.
final class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService(this._client);

  final FirebaseRemoteConfigClient _client;

  @override
  Future<void> initialize() async {
    try {
      await _client.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: kDebugMode
              ? const Duration(seconds: 10)
              : const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 12),
        ),
      );
      await _client.setDefaults(RemoteConfigDefaults.all);
      await _client.fetchAndActivate();
    } catch (_) {
      // Remote Config failures must never prevent the app from launching.
    }
  }

  @override
  int getInt(String key) {
    try {
      return _client.getValue(key).asInt();
    } catch (_) {
      // Fall back to in-code default on any error.
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is int ? defaultValue : 0;
    }
  }

  @override
  bool getBool(String key) {
    try {
      return _client.getValue(key).asBool();
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is bool ? defaultValue : false;
    }
  }

  @override
  String getString(String key) {
    try {
      return _client.getValue(key).asString();
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is String ? defaultValue : '';
    }
  }

  @override
  double getDouble(String key) {
    try {
      return _client.getValue(key).asDouble();
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      if (defaultValue is double) return defaultValue;
      if (defaultValue is num) return defaultValue.toDouble();
      return 0.0;
    }
  }
}
