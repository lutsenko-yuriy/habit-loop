/// A typed analytics event sent via [AnalyticsService].
///
/// Each subclass corresponds to one event in `docs/ANALYTICS_EVENTS.md`.
/// The domain layer is SDK-free — Firebase is only referenced in the data layer.
sealed class AnalyticsEvent {
  /// The Firebase event name (snake_case).
  String get name;

  /// Event parameters. Null values are excluded before sending to Firebase.
  Map<String, Object?> toParameters();
}

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
      if (reminderOffsetMinutes != null)
        'reminder_offset_minutes': reminderOffsetMinutes!,
      'showups_expected': showupsExpected,
    };
  }
}

/// Fired when the user manually marks a showup as done.
final class ShowupMarkedDoneEvent extends AnalyticsEvent {
  ShowupMarkedDoneEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_marked_done';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Fired when the user manually marks a showup as failed (not auto-fail).
final class ShowupMarkedFailedEvent extends AnalyticsEvent {
  ShowupMarkedFailedEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_marked_failed';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Fired when a showup is automatically transitioned to failed because the
/// showup detail screen was opened after the scheduled window has passed.
final class ShowupAutoFailedEvent extends AnalyticsEvent {
  ShowupAutoFailedEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_auto_failed';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
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
