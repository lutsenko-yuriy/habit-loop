import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Fired when the user successfully completes the pact creation wizard and
/// the pact is persisted.
final class PactCreatedEvent extends AnalyticsEvent {
  PactCreatedEvent({
    required this.scheduleType,
    required this.durationDays,
    required this.showupDurationMinutes,
    this.reminderOffsetMinutes,
    required this.showupsExpected,
  });

  /// One of `daily`, `weekly`, or `monthly`.
  final String scheduleType;

  /// Pact length in days.
  final int durationDays;

  /// Length of a single showup in minutes.
  final int showupDurationMinutes;

  /// Minutes before the showup for the reminder; `null` if no reminder was set.
  final int? reminderOffsetMinutes;

  /// Total number of showups scheduled over the full pact.
  final int showupsExpected;

  @override
  String get name => 'pact_created';

  @override
  Map<String, Object?> toParameters() {
    return {
      'schedule_type': scheduleType,
      'duration_days': durationDays,
      'showup_duration_minutes': showupDurationMinutes,
      if (reminderOffsetMinutes != null) 'reminder_offset_minutes': reminderOffsetMinutes!,
      'showups_expected': showupsExpected,
    };
  }
}

/// Fired when the user confirms stopping an active pact.
final class PactStoppedEvent extends AnalyticsEvent {
  PactStoppedEvent({
    required this.daysActive,
    required this.totalShowupsDone,
    required this.totalShowupsFailed,
    required this.totalShowupsRemaining,
  });

  /// Number of days from pact start to the stop date.
  final int daysActive;

  /// Showups marked done at the time of stopping.
  final int totalShowupsDone;

  /// Showups marked failed at the time of stopping.
  final int totalShowupsFailed;

  /// Showups still pending at the time of stopping.
  final int totalShowupsRemaining;

  @override
  String get name => 'pact_stopped';

  @override
  Map<String, Object?> toParameters() => {
        'days_active': daysActive,
        'total_showups_done': totalShowupsDone,
        'total_showups_failed': totalShowupsFailed,
        'total_showups_remaining': totalShowupsRemaining,
      };
}

/// Screen identifier for the pact creation wizard.
class PactCreationAnalyticsScreen implements AnalyticsScreen {
  const PactCreationAnalyticsScreen();

  @override
  String get name => 'pact_creation';
}

/// Screen identifier for the pact detail screen.
class PactDetailAnalyticsScreen implements AnalyticsScreen {
  const PactDetailAnalyticsScreen();

  @override
  String get name => 'pact_detail';
}
