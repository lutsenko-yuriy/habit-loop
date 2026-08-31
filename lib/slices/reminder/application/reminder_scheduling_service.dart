import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/reminder_locale_resolver.dart';
import 'package:habit_loop/slices/reminder/application/reminder_plan_context.dart';
import 'package:habit_loop/slices/reminder/application/reminder_planner.dart';

/// Resolves AppLocalizations internally (no BuildContext needed).
/// [isIOS] is constructor-injected for testability — pass Platform.isIOS at the composition root.
/// Resolves locale (async) and remote-config context, delegates the actual
/// desired-set computation to [ReminderPlanner] (HAB-254 WU1), then applies
/// the plan via [NotificationService] and logs analytics.
final class ReminderSchedulingService {
  // [systemLocale] is the device/OS locale, used only when no explicit in-app
  // override has been saved (HAB-157) — previously hardcoded to English.
  // [displayName] is the caller's resolved personalizedNameProvider value
  // (HAB-232 WU7) — read at the composition root, not here, so this class
  // stays free of a Riverpod dependency.
  const ReminderSchedulingService({
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
    required LocalePreferenceService localePreference,
    bool isIOS = false,
    Locale systemLocale = const Locale('en'),
    String? displayName,
  })  : _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS,
        _systemLocale = systemLocale,
        _displayName = displayName;

  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;
  final Locale _systemLocale;
  final String? _displayName;

  // [now] is injectable for tests.
  Future<void> scheduleRemindersForShowups({
    required Pact pact,
    required List<Showup> showups,
    DateTime? now,
    List<PactBreak> breaks = const [],
  }) async {
    if (pact.reminderOffset == null) return;

    final l10n = await ReminderLocaleResolver.resolve(
      localePreference: _localePreference,
      systemLocale: _systemLocale,
    );
    final effectiveNow = now ?? DateTime.now();

    final context = ReminderPlanContext.resolve(remoteConfig: _remoteConfig, isIOS: _isIOS, displayName: _displayName);
    final plan = ReminderPlanner.plan(
      pact: pact,
      showups: showups,
      now: effectiveNow,
      l10n: l10n,
      breaks: breaks,
      context: context,
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

      final deadline = item.deadline;
      if (deadline != null) {
        await _notificationService.scheduleDeadlineNotification(
          showup: item.showup,
          titleText: deadline.title,
          bodyText: deadline.body,
        );
      }
      scheduledCount += deadline != null ? 2 : 1;

      final hurryUp = item.hurryUp;
      if (hurryUp != null) {
        await _notificationService.scheduleHurryUpNotification(
          showup: item.showup,
          hurryUpOffset: hurryUp.offset,
          titleText: hurryUp.title,
          bodyText: hurryUp.body,
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
}
