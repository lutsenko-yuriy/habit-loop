import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Resolved configuration for the pact timeline feature, read from Remote Config.
final class PactTimelineConfig {
  const PactTimelineConfig({
    required this.enabled,
    required this.milestoneGroupingThreshold,
    required this.noGroupingTailSize,
  });

  factory PactTimelineConfig.fromRemoteConfig(RemoteConfigService rc) {
    return PactTimelineConfig(
      enabled: rc.getBool('pact_timeline_enabled'),
      milestoneGroupingThreshold: rc.getInt('pact_timeline_milestone_grouping_threshold'),
      noGroupingTailSize: rc.getInt('pact_timeline_no_grouping_tail_size'),
    );
  }

  final bool enabled;

  /// Minimum showup run length to produce a streak/group milestone (`pact_timeline_milestone_grouping_threshold`).
  final int milestoneGroupingThreshold;

  /// Number of most-recent showups always shown individually (`pact_timeline_no_grouping_tail_size`).
  final int noGroupingTailSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactTimelineConfig &&
          enabled == other.enabled &&
          milestoneGroupingThreshold == other.milestoneGroupingThreshold &&
          noGroupingTailSize == other.noGroupingTailSize;

  @override
  int get hashCode => Object.hash(enabled, milestoneGroupingThreshold, noGroupingTailSize);
}
