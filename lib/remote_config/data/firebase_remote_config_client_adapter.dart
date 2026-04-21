import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:habit_loop/remote_config/data/firebase_remote_config_service.dart';

/// Adapts the real [FirebaseRemoteConfig] SDK to the [FirebaseRemoteConfigClient]
/// interface so [FirebaseRemoteConfigService] never directly imports the SDK.
///
/// Only constructed in `main.dart`; tests use a hand-rolled fake client.
final class FirebaseRemoteConfigClientAdapter implements FirebaseRemoteConfigClient {
  FirebaseRemoteConfigClientAdapter(this._firebase);

  final FirebaseRemoteConfig _firebase;

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) {
    return _firebase.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) {
    return _firebase.setDefaults(defaults);
  }

  @override
  Future<bool> fetchAndActivate() {
    return _firebase.fetchAndActivate();
  }

  @override
  int getInt(String key) {
    return _firebase.getValue(key).asInt();
  }

  @override
  bool getBool(String key) {
    return _firebase.getValue(key).asBool();
  }

  @override
  String getString(String key) {
    return _firebase.getValue(key).asString();
  }

  @override
  double getDouble(String key) {
    return _firebase.getValue(key).asDouble();
  }
}
