import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/app_version.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Computes whether a release-gated feature flag should be enabled (HAB-207).
///
/// Pure and independently testable: [currentVersion] and [isDebugOrProfile]
/// are passed explicitly rather than read from [currentAppVersion] /
/// `kDebugMode` / `kProfileMode` directly, so tests can exercise arbitrary
/// combinations without needing real debug/profile builds.
/// [FeatureFlags.fromRemoteConfig] is the sole call site that wires in the
/// real values.
///
/// Both of the following must hold for the result to be `true`:
/// - [rawValue] (the flag's raw boolean read from Remote Config) is `true`.
/// - [isDebugOrProfile] is `true` (release-version check skipped entirely in
///   debug/profile builds), OR [releaseVersion] is non-null and
///   `isAtLeast(currentVersion, releaseVersion)` — a `null` [releaseVersion]
///   means the feature is still under construction and can never show in a
///   release build, regardless of [rawValue].
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
  });

  factory FeatureFlags.fromRemoteConfig(RemoteConfigService rc) {
    const isDebugOrProfile = kDebugMode || kProfileMode;
    return FeatureFlags._(
      languageSelectionEnabled: rc.getBool('language_selection_enabled'),
      networkSyncEnabled: rc.getBool('network_sync_enabled'),
      pactTimelineEnabled: rc.getBool('pact_timeline_enabled'),
      showupRedemptionEnabled: rc.getBool('showup_redemption_enabled'),
      aboutScreenEnabled: rc.getBool('about_screen_enabled'),
      pactBreaksEnabled: rc.getBool('pact_breaks_enabled'),
      pactChainingEnabled: resolveReleaseGatedFlag(
        rawValue: rc.getBool('pact_chaining_enabled'),
        releaseVersion: RemoteConfigDefaults.releaseVersions['pact_chaining_enabled'],
        currentVersion: currentAppVersion,
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
          pactChainingEnabled == other.pactChainingEnabled;

  @override
  int get hashCode => Object.hash(
        languageSelectionEnabled,
        networkSyncEnabled,
        pactTimelineEnabled,
        showupRedemptionEnabled,
        aboutScreenEnabled,
        pactBreaksEnabled,
        pactChainingEnabled,
      );
}
