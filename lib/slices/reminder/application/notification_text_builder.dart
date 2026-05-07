import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Pure stateless helper that builds notification title + body strings.
///
/// All methods are static — no instance, no external state, no Riverpod, no
/// Flutter imports beyond the generated [AppLocalizations] class.
///
/// Callers pass in the [AppLocalizations] they already hold from the UI layer
/// so the service itself never needs a [BuildContext].
abstract final class NotificationTextBuilder {
  /// Builds the reminder notification text for the given [variant].
  ///
  /// Variants:
  /// - `'control'` — generic reminder using [AppLocalizations.notificationReminderTitle]
  ///   and [AppLocalizations.notificationReminderBody].
  /// - `'deadline'` — urgency copy showing the clock time when the window closes
  ///   (`scheduledAt + showupDuration`), formatted as `HH:mm`.
  /// - `'time_limit'` — shows how long the user has to mark the showup done
  ///   (i.e. the [showupDuration] formatted as "Xh Ymin" or "Y min").
  /// - any other value — falls back to `'control'` behaviour.
  static ({String title, String body}) buildReminderText({
    required String variant,
    required String habitName,
    required DateTime scheduledAt,
    required Duration showupDuration,
    required AppLocalizations l10n,
  }) {
    return switch (variant) {
      'deadline' => _buildDeadlineText(
          habitName: habitName,
          scheduledAt: scheduledAt,
          showupDuration: showupDuration,
          l10n: l10n,
        ),
      'time_limit' => _buildTimeLimitText(
          habitName: habitName,
          showupDuration: showupDuration,
          l10n: l10n,
        ),
      _ => (
          title: l10n.notificationReminderTitle(habitName),
          body: l10n.notificationReminderBody,
        ),
    };
  }

  /// Builds the "missed deadline" replacement notification text.
  ///
  /// Scheduled after the showup window closes to replace (or accompany) the
  /// original reminder notification. Has no action buttons — the window has
  /// already passed.
  static ({String title, String body}) buildDeadlineExpiredText({
    required AppLocalizations l10n,
  }) {
    return (
      title: l10n.notificationMissedTitle,
      body: l10n.notificationMissedBody,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static ({String title, String body}) _buildDeadlineText({
    required String habitName,
    required DateTime scheduledAt,
    required Duration showupDuration,
    required AppLocalizations l10n,
  }) {
    final closeTime = scheduledAt.add(showupDuration);
    final timeString = _formatHHmm(closeTime);
    return (
      title: l10n.notificationDeadlineTitle(habitName),
      body: l10n.notificationDeadlineBody(timeString),
    );
  }

  static ({String title, String body}) _buildTimeLimitText({
    required String habitName,
    required Duration showupDuration,
    required AppLocalizations l10n,
  }) {
    final durationString = _formatTimeRemaining(showupDuration, l10n);
    return (
      title: l10n.notificationTimeLimitTitle(habitName),
      body: l10n.notificationTimeLimitBody(durationString),
    );
  }

  /// Formats [time] as `HH:mm` (24-hour, zero-padded).
  static String _formatHHmm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formats [remaining] as a human-readable string for the `time_limit` variant.
  ///
  /// Examples:
  /// - `Duration(minutes: 30)` → `"30 min"`
  /// - `Duration(hours: 1)` → `"1 h"`
  /// - `Duration(hours: 1, minutes: 30)` → `"1 h 30 min"`
  static String _formatTimeRemaining(Duration remaining, AppLocalizations l10n) {
    final totalMinutes = remaining.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes min';
    } else if (minutes == 0) {
      return '$hours h';
    } else {
      return '$hours h $minutes min';
    }
  }
}
