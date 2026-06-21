import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Resolved configuration for the pact timeline feature, read from Remote Config.
///
/// Sentinel value `0` in RC means "use the computed default" for
/// [noGroupingTailSize], [firstPageSize], and [nthPageSize].
final class PactTimelineConfig {
  const PactTimelineConfig({
    required this.enabled,
    required this.milestoneGroupingThreshold,
    required this.noGroupingTailSize,
    required this.firstPageSize,
    required this.nthPageSize,
  });

  factory PactTimelineConfig.fromRemoteConfig(RemoteConfigService rc) {
    final threshold = rc.getInt('pact_timeline_milestone_grouping_threshold');
    final tailRaw = rc.getInt('pact_timeline_no_grouping_tail_size');
    final firstPageRaw = rc.getInt('pact_timeline_first_page_size');
    final nthPageRaw = rc.getInt('pact_timeline_nth_page_size');

    return PactTimelineConfig(
      enabled: rc.getBool('pact_timeline_enabled'),
      milestoneGroupingThreshold: threshold,
      noGroupingTailSize: tailRaw == 0 ? threshold : tailRaw,
      firstPageSize: firstPageRaw == 0 ? 20 : firstPageRaw,
      nthPageSize: nthPageRaw == 0 ? 10 : nthPageRaw,
    );
  }

  /// Whether the pact timeline feature is enabled (`pact_timeline_enabled`).
  final bool enabled;

  /// Minimum showup run length to produce a streak/group milestone (`pact_timeline_milestone_grouping_threshold`).
  final int milestoneGroupingThreshold;

  /// Number of most-recent showups always shown individually (`pact_timeline_no_grouping_tail_size`).
  /// Resolved from the threshold when the RC value is 0.
  final int noGroupingTailSize;

  /// Showups loaded on the first timeline page (`pact_timeline_first_page_size`).
  /// Defaults to 20 when the RC value is 0.
  final int firstPageSize;

  /// Showups loaded on each subsequent page (`pact_timeline_nth_page_size`).
  /// Defaults to 10 when the RC value is 0.
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
