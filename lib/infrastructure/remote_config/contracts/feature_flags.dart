import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/app_version.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// True iff [rawValue] is true AND (debug/profile OR [releaseVersion] is set
/// and satisfied by [currentVersion]) (HAB-207). Pure — real values are
/// wired in only by [FeatureFlags.fromRemoteConfig], so tests can pass
/// anything here without needing real debug builds.
bool resolveReleaseGatedFlag({
  required bool rawValue,
  required String? releaseVersion,
  required String currentVersion,
  required bool isDebugOrProfile,
}) {
  if (!rawValue) {
    return false;
  }
  if (isDebugOrProfile) {
    return true;
  }
  return releaseVersion != null && isAtLeast(currentVersion, releaseVersion);
}

final class FeatureFlags {
  const FeatureFlags._({
    required this.languageSelectionEnabled,
    required this.networkSyncEnabled,
    required this.pactTimelineEnabled,
    required this.showupRedemptionEnabled,
    required this.aboutScreenEnabled,
    required this.pactBreaksEnabled,
    required this.pactChainingEnabled,
    required this.displayNamePersonalizationEnabled,
  });

  /// [appVersion] is the real running version (see `runningAppVersionProvider`
  /// in main.dart); defaults to [unspecifiedAppVersion] so callers that don't
  /// care about gating (most tests) always satisfy every gate.
  factory FeatureFlags.fromRemoteConfig(RemoteConfigService rc, {String appVersion = unspecifiedAppVersion}) {
    const isDebugOrProfile = kDebugMode || kProfileMode;
    return FeatureFlags._(
      languageSelectionEnabled: rc.getBool('language_selection_enabled'),
      networkSyncEnabled: rc.getBool('network_sync_enabled'),
      pactTimelineEnabled: rc.getBool('pact_timeline_enabled'),
      showupRedemptionEnabled: rc.getBool('showup_redemption_enabled'),
      aboutScreenEnabled: rc.getBool('about_screen_enabled'),
      pactBreaksEnabled: rc.getBool('pact_breaks_enabled'),
      // Release-version gating (HAB-207) starts here — flags above predate it.
      pactChainingEnabled: resolveReleaseGatedFlag(
        rawValue: rc.getBool('pact_chaining_enabled'),
        releaseVersion: RemoteConfigDefaults.releaseVersions['pact_chaining_enabled'],
        currentVersion: appVersion,
        isDebugOrProfile: isDebugOrProfile,
      ),
      // Release-gated to 0.59.0 (HAB-232 WU7), mirroring pactChainingEnabled above.
      displayNamePersonalizationEnabled: resolveReleaseGatedFlag(
        rawValue: rc.getBool('display_name_personalization_enabled'),
        releaseVersion: RemoteConfigDefaults.releaseVersions['display_name_personalization_enabled'],
        currentVersion: appVersion,
        isDebugOrProfile: isDebugOrProfile,
      ),
    );
  }

  final bool languageSelectionEnabled;
  final bool networkSyncEnabled;

  /// Whether the pact timeline screen entry point is enabled.
  final bool pactTimelineEnabled;

  /// Whether the showup redemption action is enabled on the showup detail screen.
  final bool showupRedemptionEnabled;

  /// Whether the About screen entry point is visible on the dashboard.
  final bool aboutScreenEnabled;

  /// Whether the pact-breaks feature (HAB-195) is enabled.
  final bool pactBreaksEnabled;

  /// Whether the pact-chaining feature (HAB-202) is enabled.
  final bool pactChainingEnabled;

  /// Whether display-name personalization (HAB-232) is enabled.
  final bool displayNamePersonalizationEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlags &&
          languageSelectionEnabled == other.languageSelectionEnabled &&
          networkSyncEnabled == other.networkSyncEnabled &&
          pactTimelineEnabled == other.pactTimelineEnabled &&
          showupRedemptionEnabled == other.showupRedemptionEnabled &&
          aboutScreenEnabled == other.aboutScreenEnabled &&
          pactBreaksEnabled == other.pactBreaksEnabled &&
          pactChainingEnabled == other.pactChainingEnabled &&
          displayNamePersonalizationEnabled == other.displayNamePersonalizationEnabled;

  @override
  int get hashCode => Object.hash(
        languageSelectionEnabled,
        networkSyncEnabled,
        pactTimelineEnabled,
        showupRedemptionEnabled,
        aboutScreenEnabled,
        pactBreaksEnabled,
        pactChainingEnabled,
        displayNamePersonalizationEnabled,
      );
}
