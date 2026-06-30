import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

final class FeatureFlags {
  const FeatureFlags._({
    required this.languageSelectionEnabled,
    required this.networkSyncEnabled,
    required this.pactTimelineEnabled,
    required this.showupRedemptionEnabled,
  });

  factory FeatureFlags.fromRemoteConfig(RemoteConfigService rc) {
    return FeatureFlags._(
      languageSelectionEnabled: rc.getBool('language_selection_enabled'),
      networkSyncEnabled: rc.getBool('network_sync_enabled'),
      pactTimelineEnabled: rc.getBool('pact_timeline_enabled'),
      showupRedemptionEnabled: rc.getBool('showup_redemption_enabled'),
    );
  }

  final bool languageSelectionEnabled;
  final bool networkSyncEnabled;

  /// Whether the pact timeline screen entry point is enabled.
  final bool pactTimelineEnabled;

  /// Whether the showup redemption action is enabled on the showup detail screen.
  final bool showupRedemptionEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlags &&
          languageSelectionEnabled == other.languageSelectionEnabled &&
          networkSyncEnabled == other.networkSyncEnabled &&
          pactTimelineEnabled == other.pactTimelineEnabled &&
          showupRedemptionEnabled == other.showupRedemptionEnabled;

  @override
  int get hashCode =>
      Object.hash(languageSelectionEnabled, networkSyncEnabled, pactTimelineEnabled, showupRedemptionEnabled);
}
