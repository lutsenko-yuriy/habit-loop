import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Screen view for the pact timeline screen. (HAB-116)
///
/// [pactId], [pactStatus], and [totalShowupCount] are sent via a companion
/// [logEvent] call alongside [logScreenView] — [logScreenView] only forwards
/// [AnalyticsScreen.name], not custom properties.
class PactTimelineAnalyticsScreen implements AnalyticsScreen {
  const PactTimelineAnalyticsScreen({
    required this.pactId,
    required this.pactStatus,
    required this.totalShowupCount,
  });

  final String pactId;

  /// `active` | `completed` | `stopped`
  final String pactStatus;

  final int totalShowupCount;

  @override
  String get name => 'pact_timeline';
}

/// Companion event fired after the timeline finishes loading. (HAB-116)
///
/// Carries the properties that [PactTimelineAnalyticsScreen] declares but
/// cannot pass through [logScreenView] (which forwards only the screen name).
final class PactTimelineOpenedEvent extends AnalyticsEvent {
  PactTimelineOpenedEvent({required this.pactId, required this.pactStatus, required this.milestoneCount});

  final String pactId;

  /// `active` | `completed` | `stopped`
  final String pactStatus;

  final int milestoneCount;

  @override
  String get name => 'pact_timeline_opened';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'pact_status': pactStatus,
        'milestone_count': milestoneCount,
      };
}

/// Fired when the user taps a tappable milestone on the pact timeline. (HAB-116)
final class PactTimelineMilestoneTappedEvent extends AnalyticsEvent {
  PactTimelineMilestoneTappedEvent({required this.pactId, required this.itemType});

  final String pactId;

  /// `noted_showup` | `single_showup`
  final String itemType;

  @override
  String get name => 'pact_timeline_milestone_tapped';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'item_type': itemType,
      };
}
