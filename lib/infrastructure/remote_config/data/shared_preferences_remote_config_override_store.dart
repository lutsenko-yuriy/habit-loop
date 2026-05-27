import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [RemoteConfigOverrideStore] backed by [SharedPreferences].
///
/// Overrides are persisted under the `rc_override_<key>` key prefix so they
/// survive app restarts and are distinguishable from other SharedPreferences
/// entries.
///
/// Reads are synchronous because [SharedPreferences] caches all values in
/// memory after [SharedPreferences.getInstance] completes. The caller must
/// ensure [SharedPreferences.getInstance] has resolved before constructing
/// this store (which is guaranteed in `main.dart` as `prefs` is obtained
/// before `runApp`).
///
/// **Debug and profile builds only.** Wire via [AppContainer.overrides] —
/// never in release builds.
final class SharedPreferencesRemoteConfigOverrideStore implements RemoteConfigOverrideStore {
  /// The prefix used for all override keys in SharedPreferences.
  static const String overridePrefix = 'rc_override_';

  final SharedPreferences _prefs;

  SharedPreferencesRemoteConfigOverrideStore(this._prefs);

  @override
  String? getOverride(String key) => _prefs.getString('$overridePrefix$key');

  @override
  Future<void> setOverride(String key, String value) async {
    await _prefs.setString('$overridePrefix$key', value);
  }

  @override
  Future<void> clearOverride(String key) async {
    await _prefs.remove('$overridePrefix$key');
  }

  @override
  Map<String, String> getAllOverrides() {
    final prefixedKeys = _prefs.getKeys().where((k) => k.startsWith(overridePrefix));
    return {
      for (final k in prefixedKeys) k.substring(overridePrefix.length): _prefs.getString(k)!,
    };
  }
}
