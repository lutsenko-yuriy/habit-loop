import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/reminder_planner.dart';

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
/// Resolves locale/remote-config context, delegates the actual desired-set
/// computation to [ReminderPlanner] (HAB-254 WU1), then applies the plan via
/// [NotificationService] and logs analytics.
final class ReminderSchedulingService {
  // [systemLocale] is the device/OS locale, used only when no explicit in-app
  // override has been saved (HAB-157) — previously hardcoded to English.
  const ReminderSchedulingService({
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
    required LocalePreferenceService localePreference,
    bool isIOS = false,
    Locale systemLocale = const Locale('en'),
    ReminderPlanner planner = const ReminderPlanner(),
  })  : _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS,
        _systemLocale = systemLocale,
        _planner = planner;

  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;
  final Locale _systemLocale;
  final ReminderPlanner _planner;

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
    // Clamped: RemoteConfigDefaults.intRanges is only a debug-screen UI hint,
    // not enforced at read time — an unset/blank console value returns 0,
    // which would make every showup eligible and fire right at the deadline
    // (HAB-246 audit). Sourced from intRanges rather than a hardcoded literal
    // so this and the debug pending-notifications screen can't drift apart.
    final hurryUpRange = RemoteConfigDefaults.intRanges[_kHurryUpTimeInMinutes]!;
    final hurryUpTime = Duration(
      minutes: _remoteConfig.getInt(_kHurryUpTimeInMinutes).clamp(hurryUpRange.min, hurryUpRange.max),
    );

    final plan = _planner.plan(
      pact: pact,
      showups: showups,
      now: effectiveNow,
      l10n: l10n,
      breaks: breaks,
      textVariant: variant,
      scheduleDeadline: scheduleDeadline,
      hurryUpEnabled: hurryUpEnabled,
      hurryUpTime: hurryUpTime,
      welcomeBackEnabled: _remoteConfig.getBool(_kBreakWelcomeBackEnabled),
      isIOS: _isIOS,
    );

    var scheduledCount = 0;
    var hurryUpCount = 0;
    for (final item in plan) {
      await _notificationService.scheduleShowupReminder(
        showup: item.showup,
        pact: pact,
        titleText: item.reminderTitle,
        bodyText: item.reminderBody,
      );

      if (item.includeDeadline) {
        await _notificationService.scheduleDeadlineNotification(
          showup: item.showup,
          titleText: item.deadlineTitle!,
          bodyText: item.deadlineBody!,
        );
      }

      scheduledCount += item.includeDeadline ? 2 : 1;

      if (item.includeHurryUp) {
        await _notificationService.scheduleHurryUpNotification(
          showup: item.showup,
          hurryUpOffset: item.hurryUpOffset!,
          titleText: item.hurryUpTitle!,
          bodyText: item.hurryUpBody!,
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
