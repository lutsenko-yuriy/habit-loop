import 'dart:io' show Platform;

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
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
/// [AppLocalizations] is accepted as a parameter at the call site (not stored
/// as a field) so the service can be a Riverpod singleton while each caller
/// passes the l10n it already holds from the current [BuildContext].
final class ReminderSchedulingService {
  const ReminderSchedulingService({
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
  })  : _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics;

  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;

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
    required AppLocalizations l10n,
    DateTime? now,
  }) async {
    if (pact.reminderOffset == null) return;

    final effectiveNow = now ?? DateTime.now();
    final variant = _remoteConfig.getString(_kNotificationTextVariant);
    final postDeadlineBehavior = _remoteConfig.getString(_kPostDeadlineNotificationBehavior);
    final scheduleDeadline = Platform.isIOS || postDeadlineBehavior == 'encourage';

    final deadlineText = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);

    var scheduledCount = 0;
    for (final showup in showups) {
      if (showup.status != ShowupStatus.pending) continue;
      if (!showup.scheduledAt.isAfter(effectiveNow)) continue;

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

      scheduledCount++;
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
  /// Delegates directly to [NotificationService.cancelAllRemindersForPact].
  Future<void> cancelAllRemindersForPact(String pactId) async {
    await _notificationService.cancelAllRemindersForPact(pactId);
  }
}
