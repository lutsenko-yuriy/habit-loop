import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

final class FeatureFlags {
  const FeatureFlags._({
    required this.languageSelectionEnabled,
    required this.networkSyncEnabled,
  });

  factory FeatureFlags.fromRemoteConfig(RemoteConfigService rc) {
    return FeatureFlags._(
      languageSelectionEnabled: rc.getBool('language_selection_enabled'),
      networkSyncEnabled: rc.getBool('network_sync_enabled'),
    );
  }

  final bool languageSelectionEnabled;
  final bool networkSyncEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlags &&
          languageSelectionEnabled == other.languageSelectionEnabled &&
          networkSyncEnabled == other.networkSyncEnabled;

  @override
  int get hashCode => Object.hash(languageSelectionEnabled, networkSyncEnabled);
}
