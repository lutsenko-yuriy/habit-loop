import 'package:habit_loop/l10n/generated/app_localizations.dart';

// Static helper for notification text; callers provide AppLocalizations (no BuildContext needed).
abstract final class NotificationTextBuilder {
  /// Variant dispatches copy: `'deadline'` shows closing time (`HH:mm`),
  /// `'time_limit'` shows duration left; any other value → control (generic reminder).
  ///
  /// [displayName] personalizes the title when non-null (HAB-232 WU7) —
  /// falls back to the neutral title otherwise, same "one no-name
  /// representation" contract as [personalizedNameProvider].
  static ({String title, String body}) buildReminderText({
    required String variant,
    required String habitName,
    required DateTime scheduledAt,
    required Duration showupDuration,
    required AppLocalizations l10n,
    String? displayName,
  }) {
    return switch (variant) {
      'deadline' => _buildDeadlineText(
          habitName: habitName,
          scheduledAt: scheduledAt,
          showupDuration: showupDuration,
          l10n: l10n,
          displayName: displayName,
        ),
      'time_limit' => _buildTimeLimitText(
          habitName: habitName,
          showupDuration: showupDuration,
          l10n: l10n,
          displayName: displayName,
        ),
      _ => (
          title: displayName != null
              ? l10n.notificationReminderTitlePersonalized(displayName, habitName)
              : l10n.notificationReminderTitle(habitName),
          body: l10n.notificationReminderBody,
        ),
    };
  }

  // Replacement notification after the showup window closes; no action buttons.
  static ({String title, String body}) buildDeadlineExpiredText({
    required AppLocalizations l10n,
    String? displayName,
  }) {
    return (
      title: displayName != null
          ? l10n.notificationMissedTitlePersonalized(displayName)
          : l10n.notificationMissedTitle,
      body: l10n.notificationMissedBody,
    );
  }

  // Reminder text for the first showup after a break ends (HAB-227) —
  // independent of the EXP-001 variant dispatch above; occasion-based, not a
  // text-style variant, so it always overrides regardless of the active variant.
  static ({String title, String body}) buildWelcomeBackText({
    required String habitName,
    required AppLocalizations l10n,
    String? displayName,
  }) {
    return (
      title: displayName != null
          ? l10n.notificationWelcomeBackTitlePersonalized(displayName, habitName)
          : l10n.notificationWelcomeBackTitle(habitName),
      body: l10n.notificationWelcomeBackBody,
    );
  }

  // Last-chance nudge shortly before a showup's window closes (HAB-246) —
  // deliberately avoids a literal countdown; see buildWelcomeBackText for the
  // same occasion-based (not EXP-001-variant) pattern.
  static ({String title, String body}) buildHurryUpText({
    required String habitName,
    required AppLocalizations l10n,
    String? displayName,
  }) {
    return (
      title: displayName != null
          ? l10n.notificationHurryUpTitlePersonalized(displayName, habitName)
          : l10n.notificationHurryUpTitle(habitName),
      body: l10n.notificationHurryUpBody,
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
    String? displayName,
  }) {
    final closeTime = scheduledAt.add(showupDuration);
    final timeString = _formatHHmm(closeTime);
    return (
      title: displayName != null
          ? l10n.notificationDeadlineTitlePersonalized(displayName, habitName)
          : l10n.notificationDeadlineTitle(habitName),
      body: l10n.notificationDeadlineBody(timeString),
    );
  }

  static ({String title, String body}) _buildTimeLimitText({
    required String habitName,
    required Duration showupDuration,
    required AppLocalizations l10n,
    String? displayName,
  }) {
    final durationString = _formatTimeRemaining(showupDuration, l10n);
    return (
      title: displayName != null
          ? l10n.notificationTimeLimitTitlePersonalized(displayName, habitName)
          : l10n.notificationTimeLimitTitle(habitName),
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
