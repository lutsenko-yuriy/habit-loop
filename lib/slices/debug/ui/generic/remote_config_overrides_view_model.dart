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
    this.allowedValues,
    this.intRange,
    this.valueHint,
  });

  final String key;
  final String defaultValue;
  final String? overrideValue;
  final String effectiveValue;
  final List<String>? allowedValues;
  // When non-null, shows a slider instead of a plain text field.
  final ({int min, int max})? intRange;
  // Short semantic hint shown in the edit dialog below "Default:".
  final String? valueHint;

  bool get isOverridden => overrideValue != null;
  bool get hasAllowedValues => allowedValues != null;
  bool get hasIntRange => intRange != null;
  bool get hasValueHint => valueHint != null;
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
        allowedValues: RemoteConfigDefaults.allowedValues[key],
        intRange: RemoteConfigDefaults.intRanges[key],
        valueHint: RemoteConfigDefaults.valueHints[key],
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
  }

  Future<void> clearOverride(String key) async {
    await ref.read(remoteConfigOverrideStoreProvider).clearOverride(key);
    state = _buildEntries();
  }

  Future<void> clearAllOverrides() async {
    final store = ref.read(remoteConfigOverrideStoreProvider);
    for (final key in RemoteConfigDefaults.all.keys) {
      await store.clearOverride(key);
    }
    state = _buildEntries();
  }
}

final remoteConfigOverridesViewModelProvider =
    AutoDisposeNotifierProvider<RemoteConfigOverridesViewModel, List<RemoteConfigEntry>>(
  RemoteConfigOverridesViewModel.new,
);
