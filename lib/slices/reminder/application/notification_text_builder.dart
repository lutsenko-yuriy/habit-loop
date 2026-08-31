import 'package:habit_loop/l10n/generated/app_localizations.dart';

// Static helper for notification text; callers provide AppLocalizations (no BuildContext needed).
abstract final class NotificationTextBuilder {
  /// [displayName] personalizes the title when non-null (HAB-232 WU7) —
  /// falls back to the neutral title otherwise, same "one no-name
  /// representation" contract as [personalizedNameProvider].
  static ({String title, String body}) buildReminderText({
    required String habitName,
    required AppLocalizations l10n,
    String? displayName,
  }) {
    return (
      title: displayName != null
          ? l10n.notificationReminderTitlePersonalized(displayName, habitName)
          : l10n.notificationReminderTitle(habitName),
      body: l10n.notificationReminderBody,
    );
  }

  // Replacement notification after the showup window closes; no action
  // buttons. Deliberately not personalized (HAB-232 WU7 review) — a missed
  // showup reads better as neutral, matter-of-fact copy than a name-led one.
  static ({String title, String body}) buildDeadlineExpiredText({
    required AppLocalizations l10n,
  }) {
    return (
      title: l10n.notificationMissedTitle,
      body: l10n.notificationMissedBody,
    );
  }

  // Reminder text for the first showup after a break ends (HAB-227) —
  // occasion-based, always overrides the standard reminder text above.
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
  // same occasion-based pattern.
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
}
