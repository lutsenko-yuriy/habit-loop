import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Resolved configuration for the pact timeline feature, read from Remote Config.
final class PactTimelineConfig {
  const PactTimelineConfig({
    required this.enabled,
    required this.milestoneGroupingThreshold,
    required this.noGroupingTailSize,
    required this.firstPageSize,
    required this.nthPageSize,
  });

  factory PactTimelineConfig.fromRemoteConfig(RemoteConfigService rc) {
    return PactTimelineConfig(
      enabled: rc.getBool('pact_timeline_enabled'),
      milestoneGroupingThreshold: rc.getInt('pact_timeline_milestone_grouping_threshold'),
      noGroupingTailSize: rc.getInt('pact_timeline_no_grouping_tail_size'),
      firstPageSize: rc.getInt('pact_timeline_first_page_size'),
      nthPageSize: rc.getInt('pact_timeline_nth_page_size'),
    );
  }

  final bool enabled;

  /// Minimum showup run length to produce a streak/group milestone (`pact_timeline_milestone_grouping_threshold`).
  final int milestoneGroupingThreshold;

  /// Number of most-recent showups always shown individually (`pact_timeline_no_grouping_tail_size`).
  final int noGroupingTailSize;

  /// Showups loaded on the first timeline page (`pact_timeline_first_page_size`).
  final int firstPageSize;

  /// Showups loaded on each subsequent page (`pact_timeline_nth_page_size`).
  final int nthPageSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactTimelineConfig &&
          enabled == other.enabled &&
          milestoneGroupingThreshold == other.milestoneGroupingThreshold &&
          noGroupingTailSize == other.noGroupingTailSize &&
          firstPageSize == other.firstPageSize &&
          nthPageSize == other.nthPageSize;

  @override
  int get hashCode => Object.hash(enabled, milestoneGroupingThreshold, noGroupingTailSize, firstPageSize, nthPageSize);
}
