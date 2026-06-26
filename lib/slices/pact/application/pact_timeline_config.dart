import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Resolved configuration for the pact timeline feature, read from Remote Config.
final class PactTimelineConfig {
  const PactTimelineConfig({
    required this.enabled,
    required this.milestoneGroupingThreshold,
    required this.noGroupingTailPeriodInDays,
  });

  factory PactTimelineConfig.fromRemoteConfig(RemoteConfigService rc) {
    return PactTimelineConfig(
      enabled: rc.getBool('pact_timeline_enabled'),
      milestoneGroupingThreshold: rc.getInt('pact_timeline_milestone_grouping_threshold'),
      noGroupingTailPeriodInDays: rc.getInt('pact_timeline_no_grouping_tail_period_in_days'),
    );
  }

  final bool enabled;

  /// Minimum showup run length to produce a streak/group milestone (`pact_timeline_milestone_grouping_threshold`).
  final int milestoneGroupingThreshold;

  /// Showups within this many days before now are always shown individually (`pact_timeline_no_grouping_tail_period_in_days`).
  final int noGroupingTailPeriodInDays;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactTimelineConfig &&
          enabled == other.enabled &&
          milestoneGroupingThreshold == other.milestoneGroupingThreshold &&
          noGroupingTailPeriodInDays == other.noGroupingTailPeriodInDays;

  @override
  int get hashCode => Object.hash(enabled, milestoneGroupingThreshold, noGroupingTailPeriodInDays);
}
