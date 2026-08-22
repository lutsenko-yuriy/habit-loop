import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';

// EXP-001: notification text urgency experiment.
const _kNotificationTextVariant = 'notification_text_variant';

// EXP-002: post-deadline notification behaviour (Android only).
const _kPostDeadlineNotificationBehavior = 'post_deadline_notification_behavior';

// HAB-227: kill-switch for the break-over "welcome back" reminder text.
const _kBreakWelcomeBackEnabled = 'break_welcome_back_notification_enabled';

// HAB-246: kill-switch + bounded offset for the hurry-up reminder notification.
const _kHurryUpEnabled = 'hurry_up_notification_enabled';
const _kHurryUpTimeInMinutes = 'hurry_up_time_in_minutes';

/// Resolves AppLocalizations internally (no BuildContext needed).
/// [isIOS] is constructor-injected for testability — pass Platform.isIOS at the composition root.
/// iOS cap: 64 pending notifications max, spent chronologically by actual
/// per-showup cost (reminder + deadline + hurry-up, if eligible) — see
/// [scheduleRemindersForShowups] (HAB-246).
final class ReminderSchedulingService {
  static const int _iosMaxPendingNotifications = 64;
  // [systemLocale] is the device/OS locale, used only when no explicit in-app
  // override has been saved (HAB-157) — previously hardcoded to English.
  const ReminderSchedulingService({
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
    required LocalePreferenceService localePreference,
    bool isIOS = false,
    Locale systemLocale = const Locale('en'),
  })  : _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS,
        _systemLocale = systemLocale;

  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;
  final Locale _systemLocale;

  // Qualifies showups by: pending status + scheduledAt after now + non-null reminderOffset
  // + not on break (HAB-195 WU3 — reminders must not fire while a break covers the showup).
  // EXP-002: deadline notification scheduled on iOS always; on Android only when behavior == 'encourage'.
  // [now] is injectable for tests.
  Future<void> scheduleRemindersForShowups({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
    List<PactBreak> breaks = const [],
  }) async {
    if (pact.reminderOffset == null) return;

    final savedLocale = await _localePreference.getSavedLocale() ?? _systemLocale;
    final AppLocalizations l10n = _resolveL10n(savedLocale);

    final effectiveNow = now ?? DateTime.now();
    final variant = _remoteConfig.getString(_kNotificationTextVariant);
    final postDeadlineBehavior = _remoteConfig.getString(_kPostDeadlineNotificationBehavior);
    final scheduleDeadline = _isIOS || postDeadlineBehavior == 'encourage';

    final hurryUpEnabled = _remoteConfig.getBool(_kHurryUpEnabled);
    final hurryUpTime = Duration(minutes: _remoteConfig.getInt(_kHurryUpTimeInMinutes));

    final deadlineText = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);
    final hurryUpText = NotificationTextBuilder.buildHurryUpText(habitName: pact.habitName, l10n: l10n);

    // Computed once per call, not per showup — welcome-back applies only to
    // the reminder notification; the deadline notification above always keeps
    // standard wording, per spec.
    final welcomeBackIds = _remoteConfig.getBool(_kBreakWelcomeBackEnabled)
        ? BreakDerivation.welcomeBackShowupIds(pact, breaks)
        : const <String>{};

    final qualifyingShowups = showups
        .where((s) =>
            s.status == ShowupStatus.pending &&
            s.scheduledAt.subtract(pact.reminderOffset!).isAfter(effectiveNow) &&
            !BreakDerivation.isShowupOnBreak(showup: s, breaks: breaks))
        .toList();

    // iOS spends its 64-request budget chronologically by actual per-showup
    // cost (reminder + deadline + hurry-up, if eligible) rather than at a
    // fixed rate — a pact with no eligible showups keeps its full ~32-showup
    // horizon, while eligibility-heavy pacts trade horizon depth for
    // near-term completeness (HAB-246). Android has no cap.
    List<Showup> showupsToSchedule;
    if (_isIOS) {
      final sorted = [...qualifyingShowups]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final selected = <Showup>[];
      var budget = 0;
      for (final showup in sorted) {
        final cost = 1 +
            (scheduleDeadline ? 1 : 0) +
            (_isHurryUpEligible(showup, hurryUpEnabled, hurryUpTime, effectiveNow) ? 1 : 0);
        if (budget + cost > _iosMaxPendingNotifications) break;
        budget += cost;
        selected.add(showup);
      }
      showupsToSchedule = selected;
    } else {
      showupsToSchedule = qualifyingShowups;
    }

    var scheduledCount = 0;
    var hurryUpCount = 0;
    for (final showup in showupsToSchedule) {
      final reminderText = welcomeBackIds.contains(showup.id)
          ? NotificationTextBuilder.buildWelcomeBackText(habitName: pact.habitName, l10n: l10n)
          : NotificationTextBuilder.buildReminderText(
              variant: variant,
              habitName: pact.habitName,
              scheduledAt: showup.scheduledAt,
              showupDuration: showup.duration,
              l10n: l10n,
            );

      await _notificationService.scheduleShowupReminder(
        showup: showup,
        pact: pact,
        titleText: reminderText.title,
        bodyText: reminderText.body,
      );

      if (scheduleDeadline) {
        await _notificationService.scheduleDeadlineNotification(
          showup: showup,
          titleText: deadlineText.title,
          bodyText: deadlineText.body,
        );
      }

      scheduledCount += scheduleDeadline ? 2 : 1;

      if (_isHurryUpEligible(showup, hurryUpEnabled, hurryUpTime, effectiveNow)) {
        await _notificationService.scheduleHurryUpNotification(
          showup: showup,
          hurryUpOffset: hurryUpTime,
          titleText: hurryUpText.title,
          bodyText: hurryUpText.body,
        );
        scheduledCount += 1;
        hurryUpCount += 1;
      }
    }

    if (scheduledCount > 0) {
      await _analytics.logEvent(
        NotificationsScheduledEvent(
          pactId: pact.id,
          notificationsCount: scheduledCount,
          reminderOffsetMinutes: pact.reminderOffset!.inMinutes,
          hurryUpCount: hurryUpCount,
        ),
      );
    }
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

  Future<void> cancelRemindersForShowup(String showupId) async {
    await _notificationService.cancelShowupReminder(showupId);
  }

  // Pass showupIds for deterministic cancellation (works after cold restart).
  Future<void> cancelAllRemindersForPact(
    String pactId, {
    List<String> showupIds = const [],
  }) async {
    await _notificationService.cancelAllRemindersForPact(pactId, showupIds: showupIds);
  }

  // lookupAppLocalizations throws for unsupported locales — catches and falls back to English.
  static AppLocalizations _resolveL10n(Locale locale) {
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
