import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Resolved configuration for the pact timeline feature, read from Remote Config.
final class PactTimelineConfig {
  const PactTimelineConfig({
    required this.enabled,
    required this.noGroupingTailPeriodInDays,
  });

  factory PactTimelineConfig.fromRemoteConfig(RemoteConfigService rc) {
    return PactTimelineConfig(
      enabled: rc.getBool('pact_timeline_enabled'),
      noGroupingTailPeriodInDays: rc.getInt('pact_timeline_no_grouping_tail_period_in_days'),
    );
  }

  final bool enabled;

  /// Showups within this many days before now are always shown individually (`pact_timeline_no_grouping_tail_period_in_days`).
  final int noGroupingTailPeriodInDays;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactTimelineConfig &&
          enabled == other.enabled &&
          noGroupingTailPeriodInDays == other.noGroupingTailPeriodInDays;

  @override
  int get hashCode => Object.hash(enabled, noGroupingTailPeriodInDays);
}
