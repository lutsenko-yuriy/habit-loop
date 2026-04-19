import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:habit_loop/remote_config/data/firebase_remote_config_service.dart';

/// Adapts the real [FirebaseRemoteConfig] SDK to the [FirebaseRemoteConfigClient]
/// interface so [FirebaseRemoteConfigService] never directly imports the SDK.
///
/// Only constructed in `main.dart`; tests use a hand-rolled fake client.
final class FirebaseRemoteConfigClientAdapter
    implements FirebaseRemoteConfigClient {
  FirebaseRemoteConfigClientAdapter(this._firebase);

  final FirebaseRemoteConfig _firebase;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) {
    return _firebase.setConfigSettings(settings);
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
  RemoteConfigValue getValue(String key) {
    return _firebase.getValue(key);
  }
}
