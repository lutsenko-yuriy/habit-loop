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
  const ReminderSchedulingService({
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
    required LocalePreferenceService localePreference,
    bool isIOS = false,
  })  : _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS;

  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;

  // Qualifies showups by: pending status + scheduledAt after now + non-null reminderOffset.
  // EXP-002: deadline notification scheduled on iOS always; on Android only when behavior == 'encourage'.
  // [now] is injectable for tests.
  Future<void> scheduleRemindersForShowups({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
  }) async {
    if (pact.reminderOffset == null) return;

    final savedLocale = await _localePreference.getSavedLocale() ?? const Locale('en');
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

    var scheduledCount = 0;
    for (final showup in showupsToSchedule) {
      final reminderText = NotificationTextBuilder.buildReminderText(
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
    }

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
