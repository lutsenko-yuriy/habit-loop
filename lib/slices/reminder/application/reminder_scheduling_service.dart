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

/// Remote Config key for the EXP-001 notification text urgency experiment.
const _kNotificationTextVariant = 'notification_text_variant';

/// Remote Config key for the EXP-002 post-deadline notification behaviour
/// experiment (Android only).
const _kPostDeadlineNotificationBehavior = 'post_deadline_notification_behavior';

/// Application-layer orchestrator for reminder notification scheduling.
///
/// Reads Remote Config for both experiment keys, delegates text building to
/// [NotificationTextBuilder], and calls [NotificationService] methods.
///
/// Resolves [AppLocalizations] internally via [LocalePreferenceService] so
/// callers (view models, background services) need no BuildContext and carry
/// no locale dependency. The saved locale is fetched on every
/// [scheduleRemindersForShowups] call; falls back to English when no locale is
/// saved or the saved locale is unsupported.
///
/// [isIOS] is injected as a constructor parameter rather than calling
/// `Platform.isIOS` directly, keeping the service fully testable on any host
/// platform.  Pass `isIOS: Platform.isIOS` at the composition root
/// (`app_providers.dart`).
///
/// ## iOS 64-notification cap
///
/// iOS allows at most 64 pending local notifications at a time. Since we
/// schedule 2 notifications per showup on iOS (reminder + deadline), the
/// effective cap is 32 showups per scheduling pass. Any qualifying showups
/// beyond position 32 are silently dropped — this is expected behaviour, not
/// an error. As showups are completed or cancelled their notifications are
/// removed, making room for future ones on the next dashboard load.
final class ReminderSchedulingService {
  // iOS allows at most 64 pending local notifications; we use 2 per showup
  // on iOS (reminder + deadline).
  static const int _iosMaxPendingNotifications = 64;
  static const int _notificationsPerShowupIos = 2; // reminder + deadline
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

  /// Schedules reminder (and, where applicable, deadline) notifications for
  /// each qualifying showup in [showups].
  ///
  /// A showup qualifies when all three conditions hold:
  /// 1. Its [Showup.status] is [ShowupStatus.pending].
  /// 2. Its [Showup.scheduledAt] is strictly after [now].
  /// 3. [pact.reminderOffset] is non-null.
  ///
  /// If [pact.reminderOffset] is `null`, this method returns immediately
  /// without scheduling anything.
  ///
  /// Platform branching for deadline notifications (EXP-002):
  /// - **iOS:** always schedules the deadline replacement notification.
  /// - **Android + `post_deadline_notification_behavior == 'encourage'`:**
  ///   schedules the deadline replacement notification.
  /// - **Android + any other value (default `'dismiss'`):** skips the deadline
  ///   replacement notification.
  ///
  /// After all scheduling completes, fires [NotificationsScheduledEvent] if at
  /// least one notification was scheduled.
  ///
  /// The [now] parameter is injectable so tests can control the clock.
  Future<void> scheduleRemindersForShowups({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
  }) async {
    if (pact.reminderOffset == null) return;

    // Resolve locale from saved preference; fall back to English.
    final savedLocale = await _localePreference.getSavedLocale() ?? const Locale('en');
    final AppLocalizations l10n = _resolveL10n(savedLocale);

    final effectiveNow = now ?? DateTime.now();
    final variant = _remoteConfig.getString(_kNotificationTextVariant);
    final postDeadlineBehavior = _remoteConfig.getString(_kPostDeadlineNotificationBehavior);
    final scheduleDeadline = _isIOS || postDeadlineBehavior == 'encourage';

    final deadlineText = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);

    // Filter qualifying showups first so we can apply the iOS cap correctly.
    final qualifyingShowups = showups.where((s) {
      if (s.status != ShowupStatus.pending) return false;
      if (!s.scheduledAt.subtract(pact.reminderOffset!).isAfter(effectiveNow)) return false;
      return true;
    }).toList();

    // iOS allows at most 64 pending local notifications. On iOS we schedule
    // 2 per showup (reminder + deadline), so the effective cap is 32 showups.
    // On Android there is no practical cap.
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

  /// Cancels both the reminder and deadline notifications for a single showup.
  ///
  /// Delegates directly to [NotificationService.cancelShowupReminder].
  Future<void> cancelRemindersForShowup(String showupId) async {
    await _notificationService.cancelShowupReminder(showupId);
  }

  /// Cancels all pending notifications for a pact (called on stop-pact).
  ///
  /// Pass [showupIds] whenever the caller has access to the pact's showup IDs —
  /// this enables deterministic cancellation that works after a cold restart.
  Future<void> cancelAllRemindersForPact(
    String pactId, {
    List<String> showupIds = const [],
  }) async {
    await _notificationService.cancelAllRemindersForPact(pactId, showupIds: showupIds);
  }

  /// Resolves [AppLocalizations] for [locale], falling back to English when the
  /// locale code is not in [AppLocalizations.supportedLocales].
  ///
  /// [lookupAppLocalizations] throws [FlutterError] for unsupported locales, so
  /// this wrapper catches that and returns English l10n instead.
  static AppLocalizations _resolveL10n(Locale locale) {
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
