import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Thin abstraction over the Firebase Remote Config SDK methods used by this app.
///
/// Exists so tests can inject a fake without depending on the real Firebase SDK.
/// All value-retrieval methods return plain Dart primitives — no Firebase SDK
/// types leak through this interface, so test fakes need no firebase_remote_config
/// import.
abstract interface class FirebaseRemoteConfigClient {
  /// Applies fetch timeout and minimum fetch interval settings.
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  });

  /// Registers in-code default values that are used before a successful fetch.
  Future<void> setDefaults(Map<String, dynamic> defaults);

  /// Fetches and activates the latest Remote Config values.
  ///
  /// Returns `true` if new values were activated.
  Future<bool> fetchAndActivate();

  /// Returns the int value for [key].
  ///
  /// Returns `0` if the key is absent or cannot be parsed as int.
  int getInt(String key);

  /// Returns the bool value for [key].
  ///
  /// Returns `false` if the key is absent or cannot be parsed as bool.
  bool getBool(String key);

  /// Returns the string value for [key].
  ///
  /// Returns `''` if the key is absent.
  String getString(String key);

  /// Returns the double value for [key].
  ///
  /// Returns `0.0` if the key is absent or cannot be parsed as double.
  double getDouble(String key);
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
        fetchTimeout: !kReleaseMode ? const Duration(seconds: 10) : const Duration(seconds: 15),
        minimumFetchInterval: !kReleaseMode ? Duration.zero : const Duration(hours: 12),
      );
      await _client.setDefaults(RemoteConfigDefaults.all);
    } catch (_) {
      // Remote Config failures must never prevent the app from launching.
      return;
    }
    // Fire-and-forget the network fetch so a poor connection never blocks app
    // startup. In-code defaults (applied above) are available immediately;
    // fresh values activate in the background when the network is reachable.
    unawaited(_fetchAndActivateSilently());
  }

  Future<void> _fetchAndActivateSilently() async {
    try {
      await _client.fetchAndActivate();
    } catch (_) {
      // Network failures are expected offline — swallow silently.
    }
  }

  @override
  int getInt(String key) {
    try {
      return _client.getInt(key);
    } catch (_) {
      // Fall back to in-code default on any error.
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is int ? defaultValue : 0;
    }
  }

  @override
  bool getBool(String key) {
    try {
      return _client.getBool(key);
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is bool ? defaultValue : false;
    }
  }

  @override
  String getString(String key) {
    try {
      return _client.getString(key);
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      return defaultValue is String ? defaultValue : '';
    }
  }

  @override
  double getDouble(String key) {
    try {
      return _client.getDouble(key);
    } catch (_) {
      final defaultValue = RemoteConfigDefaults.all[key];
      if (defaultValue is double) return defaultValue;
      if (defaultValue is num) return defaultValue.toDouble();
      return 0.0;
    }
  }
}
