import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

final class RemoteConfigEntry {
  const RemoteConfigEntry({
    required this.key,
    required this.defaultValue,
    required this.overrideValue,
    required this.effectiveValue,
    required this.isFeatureToggle,
    this.allowedValues,
    this.intRange,
    this.valueHint,
    this.minVersion,
  });

  final String key;
  final String defaultValue;
  final String? overrideValue;
  final String effectiveValue;
  final bool isFeatureToggle;
  final List<String>? allowedValues;
  // When non-null, shows a slider instead of a plain text field.
  final ({int min, int max})? intRange;
  // Short semantic hint shown in the edit dialog below "Default:".
  final String? valueHint;
  // Minimum app version this flag became available on (HAB-207 release-version
  // gating data), when known. Most keys have none — the map is deliberately sparse.
  final String? minVersion;

  bool get isOverridden => overrideValue != null;
  bool get hasAllowedValues => allowedValues != null;
  bool get hasIntRange => intRange != null;
  bool get hasValueHint => valueHint != null;
  bool get hasMinVersion => minVersion != null;
}

// Debug/profile only. Rebuilds state immediately on override changes (no hot-restart needed).
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
        isFeatureToggle: RemoteConfigDefaults.featureToggleKeys.contains(key),
        allowedValues: RemoteConfigDefaults.allowedValues[key],
        intRange: RemoteConfigDefaults.intRanges[key],
        valueHint: RemoteConfigDefaults.valueHints[key],
        minVersion: RemoteConfigDefaults.releaseVersions[key],
      );
    }).toList();
  }

  String _readEffective(RemoteConfigService service, String key, Object? defaultRaw) {
    if (defaultRaw is int) return service.getInt(key).toString();
    if (defaultRaw is bool) return service.getBool(key).toString();
    if (defaultRaw is double) return service.getDouble(key).toString();
    return service.getString(key);
  }

  Future<void> setOverride(String key, String value) async {
    await ref.read(remoteConfigOverrideStoreProvider).setOverride(key, value);
    state = _buildEntries();
    ref.invalidate(featureFlagsProvider);
  }

  Future<void> clearOverride(String key) async {
    await ref.read(remoteConfigOverrideStoreProvider).clearOverride(key);
    state = _buildEntries();
    ref.invalidate(featureFlagsProvider);
  }

  Future<void> clearAllOverrides() async {
    final store = ref.read(remoteConfigOverrideStoreProvider);
    for (final key in RemoteConfigDefaults.all.keys) {
      await store.clearOverride(key);
    }
    state = _buildEntries();
    ref.invalidate(featureFlagsProvider);
  }
}

final remoteConfigOverridesViewModelProvider =
    AutoDisposeNotifierProvider<RemoteConfigOverridesViewModel, List<RemoteConfigEntry>>(
  RemoteConfigOverridesViewModel.new,
);
