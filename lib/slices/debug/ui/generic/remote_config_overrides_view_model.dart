import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// One Remote Config entry — key, defaults, active override, and effective value.
///
/// The effective value reflects what [RemoteConfigService] currently returns for
/// this key. When an override is set via [RemoteConfigOverrideStore], the
/// effective value equals the override (if parseable by the service); otherwise
/// it falls back to the remote / in-code default.
final class RemoteConfigEntry {
  const RemoteConfigEntry({
    required this.key,
    required this.defaultValue,
    required this.overrideValue,
    required this.effectiveValue,
    this.allowedValues,
    this.intRange,
    this.valueHint,
  });

  /// The Remote Config key name, e.g. `'max_active_pacts'`.
  final String key;

  /// String representation of the in-code default from [RemoteConfigDefaults].
  final String defaultValue;

  /// The current string-encoded override stored in [RemoteConfigOverrideStore],
  /// or `null` when no override is set.
  final String? overrideValue;

  /// What [RemoteConfigService] currently returns for this key, as a string.
  final String effectiveValue;

  /// Fixed set of accepted values for enum-like keys, or `null` when any value
  /// is acceptable (e.g. numeric keys). Sourced from [RemoteConfigDefaults.allowedValues].
  final List<String>? allowedValues;

  /// Bounded integer range `(min, max)` for slider rendering, or `null` for
  /// free-text keys. Sourced from [RemoteConfigDefaults.intRanges].
  ///
  /// When non-null (and [hasAllowedValues] is `false`), the debug override
  /// screen shows a slider constrained to this range instead of a plain text
  /// field, making it easy to explore the full value space without typos.
  final ({int min, int max})? intRange;

  /// Optional short hint explaining the semantic meaning of specific values for
  /// this key (e.g. what 0 / 50 / 100 mean). Shown in the edit dialog below
  /// the "Default:" line. `null` when no additional context is needed.
  /// Sourced from [RemoteConfigDefaults.valueHints].
  final String? valueHint;

  bool get isOverridden => overrideValue != null;
  bool get hasAllowedValues => allowedValues != null;
  bool get hasIntRange => intRange != null;
  bool get hasValueHint => valueHint != null;
}

/// ViewModel for the debug Remote Config overrides screen.
///
/// Exposes the full list of [RemoteConfigDefaults.all] keys with their
/// effective values and override status. Provides [setOverride],
/// [clearOverride], and [clearAllOverrides] to mutate the
/// [RemoteConfigOverrideStore] and immediately rebuild the state so the UI
/// reflects changes without a hot-restart.
///
/// **Debug and profile builds only.** The entry point is gated on
/// `kDebugMode || kProfileMode` in the dashboard. In release builds,
/// [remoteConfigOverrideStoreProvider] defaults to [NoopRemoteConfigOverrideStore],
/// making all store mutations silent no-ops.
class RemoteConfigOverridesViewModel extends AutoDisposeNotifier<List<RemoteConfigEntry>> {
  @override
  List<RemoteConfigEntry> build() => _buildEntries();

  List<RemoteConfigEntry> _buildEntries() {
    final store = ref.read(remoteConfigOverrideStoreProvider);
    final service = ref.read(remoteConfigServiceProvider);

    return RemoteConfigDefaults.all.entries.map((e) {
      final key = e.key;
      final defaultRaw = e.value;
      return RemoteConfigEntry(
        key: key,
        defaultValue: defaultRaw.toString(),
        overrideValue: store.getOverride(key),
        effectiveValue: _readEffective(service, key, defaultRaw),
        allowedValues: RemoteConfigDefaults.allowedValues[key],
        intRange: RemoteConfigDefaults.intRanges[key],
        valueHint: RemoteConfigDefaults.valueHints[key],
      );
    }).toList();
  }

  /// Reads the effective value using the typed getter that matches [defaultRaw].
  String _readEffective(RemoteConfigService service, String key, Object? defaultRaw) {
    if (defaultRaw is int) return service.getInt(key).toString();
    if (defaultRaw is bool) return service.getBool(key).toString();
    if (defaultRaw is double) return service.getDouble(key).toString();
    return service.getString(key);
  }

  /// Persists [value] as the string-encoded override for [key] and refreshes state.
  ///
  /// If [key] is `'debug_auth_state'`, also invalidates [authStateChangesProvider]
  /// so the UI immediately reflects the new simulated auth state.
  Future<void> setOverride(String key, String value) async {
    await ref.read(remoteConfigOverrideStoreProvider).setOverride(key, value);
    if (key == 'debug_auth_state') ref.invalidate(authStateChangesProvider);
    state = _buildEntries();
  }

  /// Removes the override for [key] and refreshes state.
  ///
  /// If [key] is `'debug_auth_state'`, also invalidates [authStateChangesProvider].
  Future<void> clearOverride(String key) async {
    await ref.read(remoteConfigOverrideStoreProvider).clearOverride(key);
    if (key == 'debug_auth_state') ref.invalidate(authStateChangesProvider);
    state = _buildEntries();
  }

  /// Removes all overrides for every key in [RemoteConfigDefaults.all].
  ///
  /// Always invalidates [authStateChangesProvider] since `debug_auth_state`
  /// may have been active and is now being cleared.
  Future<void> clearAllOverrides() async {
    final store = ref.read(remoteConfigOverrideStoreProvider);
    for (final key in RemoteConfigDefaults.all.keys) {
      await store.clearOverride(key);
    }
    ref.invalidate(authStateChangesProvider);
    state = _buildEntries();
  }
}

final remoteConfigOverridesViewModelProvider =
    AutoDisposeNotifierProvider<RemoteConfigOverridesViewModel, List<RemoteConfigEntry>>(
  RemoteConfigOverridesViewModel.new,
);
