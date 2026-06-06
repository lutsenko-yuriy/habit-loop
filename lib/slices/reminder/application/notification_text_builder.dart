import 'package:habit_loop/l10n/generated/app_localizations.dart';

// Static helper for notification text; callers provide AppLocalizations (no BuildContext needed).
abstract final class NotificationTextBuilder {
  /// Variant dispatches copy: `'deadline'` shows closing time (`HH:mm`),
  /// `'time_limit'` shows duration left; any other value → control (generic reminder).
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

  // Replacement notification after the showup window closes; no action buttons.
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

  static String _formatHHmm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // 30min → "30 min"; 1h → "1 h"; 1h 30min → "1 h 30 min".
  static String _formatTimeRemaining(Duration remaining, AppLocalizations l10n) {
    final totalMinutes = remaining.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return l10n.notificationDurationMinutes(minutes);
    } else if (minutes == 0) {
      return l10n.notificationDurationHours(hours);
    } else {
      return '${l10n.notificationDurationHours(hours)} ${l10n.notificationDurationMinutes(minutes)}';
    }
  }
}
