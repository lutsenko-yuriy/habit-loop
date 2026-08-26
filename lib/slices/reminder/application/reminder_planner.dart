import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';
import 'package:habit_loop/slices/reminder/application/planned_reminder.dart';

/// Pure desired-set computation, extracted from [ReminderSchedulingService]
/// (HAB-254 WU1) so the same logic can drive both immediate scheduling and
/// the notification-reconciliation diff (HAB-254 WU2). Takes already-resolved
/// context (locale, remote-config values) as plain parameters — it does not
/// read remote config, locale prefs, or the notification service itself, and
/// has no side effects.
///
/// iOS cap: 64 pending notifications max, spent chronologically by actual
/// per-showup cost (reminder + deadline + hurry-up, if eligible) — see [plan].
final class ReminderPlanner {
  static const int iosMaxPendingNotifications = 64;

  const ReminderPlanner();

  // Qualifies showups by: pending status + scheduledAt after now + non-null reminderOffset
  // + not on break (HAB-195 WU3 — reminders must not fire while a break covers the showup).
  List<PlannedReminder> plan({
    required Pact pact,
    required List<Showup> showups,
    required DateTime now,
    required AppLocalizations l10n,
    List<PactBreak> breaks = const [],
    String textVariant = 'control',
    bool scheduleDeadline = false,
    bool hurryUpEnabled = false,
    Duration hurryUpTime = Duration.zero,
    bool welcomeBackEnabled = true,
    bool isIOS = false,
  }) {
    if (pact.reminderOffset == null) return const [];

    final deadlineText = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);
    final hurryUpText = NotificationTextBuilder.buildHurryUpText(habitName: pact.habitName, l10n: l10n);

    // Computed once, not per showup — welcome-back applies only to the
    // reminder notification; the deadline notification always keeps standard
    // wording, per spec.
    final welcomeBackIds = welcomeBackEnabled ? BreakDerivation.welcomeBackShowupIds(pact, breaks) : const <String>{};

    final qualifyingShowups = showups
        .where((s) =>
            s.status == ShowupStatus.pending &&
            s.scheduledAt.subtract(pact.reminderOffset!).isAfter(now) &&
            !BreakDerivation.isShowupOnBreak(showup: s, breaks: breaks))
        .toList();

    // iOS spends its 64-request budget chronologically by actual per-showup
    // cost (reminder + deadline + hurry-up, if eligible) rather than at a
    // fixed rate — a pact with no eligible showups keeps its full ~32-showup
    // horizon, while eligibility-heavy pacts trade horizon depth for
    // near-term completeness (HAB-246). Android has no cap.
    List<Showup> showupsToPlan;
    if (isIOS) {
      final sorted = [...qualifyingShowups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final selected = <Showup>[];
      var budget = 0;
      for (final showup in sorted) {
        final cost =
            1 + (scheduleDeadline ? 1 : 0) + (_isHurryUpEligible(showup, hurryUpEnabled, hurryUpTime, now) ? 1 : 0);
        if (budget + cost > iosMaxPendingNotifications) break;
        budget += cost;
        selected.add(showup);
      }
      showupsToPlan = selected;
    } else {
      showupsToPlan = qualifyingShowups;
    }

    return [
      for (final showup in showupsToPlan)
        _planShowup(
          pact: pact,
          showup: showup,
          l10n: l10n,
          textVariant: textVariant,
          scheduleDeadline: scheduleDeadline,
          deadlineText: deadlineText,
          hurryUpText: hurryUpText,
          hurryUpEnabled: hurryUpEnabled,
          hurryUpTime: hurryUpTime,
          now: now,
          isWelcomeBack: welcomeBackIds.contains(showup.id),
        ),
    ];
  }

  PlannedReminder _planShowup({
    required Pact pact,
    required Showup showup,
    required AppLocalizations l10n,
    required String textVariant,
    required bool scheduleDeadline,
    required ({String title, String body}) deadlineText,
    required ({String title, String body}) hurryUpText,
    required bool hurryUpEnabled,
    required Duration hurryUpTime,
    required DateTime now,
    required bool isWelcomeBack,
  }) {
    final reminderText = isWelcomeBack
        ? NotificationTextBuilder.buildWelcomeBackText(habitName: pact.habitName, l10n: l10n)
        : NotificationTextBuilder.buildReminderText(
            variant: textVariant,
            habitName: pact.habitName,
            scheduledAt: showup.scheduledAt,
            showupDuration: showup.duration,
            l10n: l10n,
          );

    final includeHurryUp = _isHurryUpEligible(showup, hurryUpEnabled, hurryUpTime, now);

    return PlannedReminder(
      showup: showup,
      reminderTitle: reminderText.title,
      reminderBody: reminderText.body,
      includeDeadline: scheduleDeadline,
      deadlineTitle: scheduleDeadline ? deadlineText.title : null,
      deadlineBody: scheduleDeadline ? deadlineText.body : null,
      includeHurryUp: includeHurryUp,
      hurryUpOffset: includeHurryUp ? hurryUpTime : null,
      hurryUpTitle: includeHurryUp ? hurryUpText.title : null,
      hurryUpBody: includeHurryUp ? hurryUpText.body : null,
    );
  }

  // Eligible iff the toggle is on, the showup's window is long enough
  // (duration >= 3 × hurryUpTime, per spec) and its fire time still lies in
  // the future. Given eligibility implies duration - hurryUpTime >= 0, the
  // fire-time check can only trip for a showup that was already excluded by
  // the reminder-fire-time qualifying filter above — kept here as
  // defense-in-depth, matching the transport layer's own guard (HAB-246).
  bool _isHurryUpEligible(Showup showup, bool enabled, Duration hurryUpTime, DateTime now) {
    if (!enabled) return false;
    if (showup.duration < hurryUpTime * 3) return false;
    final fireAt = showup.scheduledAt.add(showup.duration).subtract(hurryUpTime);
    return fireAt.isAfter(now);
  }
}
