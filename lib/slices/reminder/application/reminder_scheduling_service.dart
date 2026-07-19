import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/pact.dart';
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

/// Resolves AppLocalizations internally (no BuildContext needed).
/// [isIOS] is constructor-injected for testability — pass Platform.isIOS at the composition root.
/// iOS cap: 64 pending notifications max (2 per showup = 32 showups max per pass).
final class ReminderSchedulingService {
  static const int _iosMaxPendingNotifications = 64;
  // 2 per showup on iOS (reminder + deadline); cap = 64 / 2 = 32 showups.
  static const int _notificationsPerShowupIos = 2;
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

  // Qualifies showups by: pending status + scheduledAt after now + non-null reminderOffset.
  // EXP-002: deadline notification scheduled on iOS always; on Android only when behavior == 'encourage'.
  // [now] is injectable for tests.
  Future<void> scheduleRemindersForShowups({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
  }) async {
    if (pact.reminderOffset == null) return;

    final savedLocale = await _localePreference.getSavedLocale() ?? _systemLocale;
    final AppLocalizations l10n = _resolveL10n(savedLocale);

    final effectiveNow = now ?? DateTime.now();
    final variant = _remoteConfig.getString(_kNotificationTextVariant);
    final postDeadlineBehavior = _remoteConfig.getString(_kPostDeadlineNotificationBehavior);
    final scheduleDeadline = _isIOS || postDeadlineBehavior == 'encourage';

    final deadlineText = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);

    final qualifyingShowups = showups.where((s) {
      if (s.status != ShowupStatus.pending) return false;
      if (!s.scheduledAt.subtract(pact.reminderOffset!).isAfter(effectiveNow)) return false;
      return true;
    }).toList();

    final maxShowups = _isIOS ? (_iosMaxPendingNotifications ~/ _notificationsPerShowupIos) : qualifyingShowups.length;
    final showupsToSchedule = qualifyingShowups.take(maxShowups).toList();

    // TEMP DIAGNOSTIC (HAB-179) — remove after confirming/refuting the
    // platform-channel-latency theory via a live CI dispatch.
    // ignore: avoid_print
    print('HAB-179 DIAG: scheduling loop start, count=${showupsToSchedule.length}, t=${DateTime.now()}');

    var scheduledCount = 0;
    for (final showup in showupsToSchedule) {
      final reminderText = NotificationTextBuilder.buildReminderText(
        variant: variant,
        habitName: pact.habitName,
        scheduledAt: showup.scheduledAt,
        showupDuration: showup.duration,
        l10n: l10n,
      );

      // ignore: avoid_print
      print('HAB-179 DIAG: before scheduleShowupReminder #$scheduledCount, t=${DateTime.now()}');
      await _notificationService.scheduleShowupReminder(
        showup: showup,
        pact: pact,
        titleText: reminderText.title,
        bodyText: reminderText.body,
      );
      // ignore: avoid_print
      print('HAB-179 DIAG: after scheduleShowupReminder #$scheduledCount, t=${DateTime.now()}');

      if (scheduleDeadline) {
        await _notificationService.scheduleDeadlineNotification(
          showup: showup,
          titleText: deadlineText.title,
          bodyText: deadlineText.body,
        );
      }

      scheduledCount += scheduleDeadline ? 2 : 1;
    }
    // ignore: avoid_print
    print('HAB-179 DIAG: scheduling loop end, scheduledCount=$scheduledCount, t=${DateTime.now()}');

    if (scheduledCount > 0) {
      await _analytics.logEvent(
        NotificationsScheduledEvent(
          pactId: pact.id,
          notificationsCount: scheduledCount,
          reminderOffsetMinutes: pact.reminderOffset!.inMinutes,
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
