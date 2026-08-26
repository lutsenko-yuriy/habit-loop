import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/planned_reminder.dart';
import 'package:habit_loop/slices/reminder/application/reminder_plan_context.dart';
import 'package:habit_loop/slices/reminder/application/reminder_planner.dart';

const _kReconciliationEnabled = 'notification_reconciliation_enabled';

/// Catches drift between derived pact state (on-break status, showup
/// status, locale, RC flags) and the notifications actually registered with
/// the OS (HAB-254) — a stateless desired-vs-actual diff, re-run on demand
/// rather than tracked incrementally.
///
/// [reconcile] loads every remindable active pact, computes its desired
/// notification set via [ReminderPlanner] (the same computation
/// [ReminderSchedulingService] uses for one-shot scheduling), reads the
/// actually-pending set via [NotificationService.getPendingNotifications],
/// and applies the diff: schedules whichever individual notification kind
/// (reminder/deadline/hurry-up) is desired but missing, and cancels any
/// showup whose notifications are pending but no longer desired.
///
/// **v1 scope guards** (see `docs/knowledge/notes/HAB-254.md`): diffs by
/// notification *id* only, not title/body — a showup whose desired copy
/// changed (e.g. a stale locale) without touching its on/off-break status
/// keeps stale text until it is otherwise rescheduled (HAB-229's/the
/// language-picker bug's follow-up). Cancellation only ever targets ids
/// attributable to a showup this pact still tracks — an orphaned id from a
/// deleted/reseeded showup is left alone (HAB-229, tracked separately).
///
/// No trigger is wired to this yet — that is HAB-254 WU3's job
/// (`AppLifecycleReconciler`, `SyncService.pullCompleted`).
final class NotificationReconciliationService {
  const NotificationReconciliationService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactBreakRepository pactBreakRepository,
    required NotificationService notificationService,
    required RemoteConfigService remoteConfig,
    required AnalyticsService analytics,
    required LocalePreferenceService localePreference,
    bool isIOS = false,
    Locale systemLocale = const Locale('en'),
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _pactBreakRepository = pactBreakRepository,
        _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS,
        _systemLocale = systemLocale;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactBreakRepository _pactBreakRepository;
  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;
  final Locale _systemLocale;

  // [now] is injectable for tests.
  Future<void> reconcile({DateTime? now}) async {
    if (!_remoteConfig.getBool(_kReconciliationEnabled)) return;

    final activePacts = await _pactRepository.getActivePacts();
    final remindablePacts = activePacts.where((p) => p.reminderOffset != null).toList();
    if (remindablePacts.isEmpty) return;

    final effectiveNow = now ?? DateTime.now();
    final savedLocale = await _localePreference.getSavedLocale() ?? _systemLocale;
    final AppLocalizations l10n = _resolveL10n(savedLocale);
    final context = ReminderPlanContext.resolve(remoteConfig: _remoteConfig, isIOS: _isIOS);
    final actualIds = (await _notificationService.getPendingNotifications()).map((n) => n.id).toSet();

    var rescheduledCount = 0;
    var cancelledCount = 0;

    for (final pact in remindablePacts) {
      final showups = await _showupRepository.getShowupsForPact(pact.id);
      final breaks = await _pactBreakRepository.getBreaksForPact(pact.id);

      final plan = ReminderPlanner.plan(
        pact: pact,
        showups: showups,
        now: effectiveNow,
        l10n: l10n,
        breaks: breaks,
        context: context,
        isIOS: _isIOS,
      );
      final desiredShowupIds = plan.map((item) => item.showup.id).toSet();

      for (final item in plan) {
        rescheduledCount += await _applyMissing(item, pact, actualIds);
      }

      for (final showup in showups) {
        if (desiredShowupIds.contains(showup.id)) continue;
        final hasStalePending = actualIds.contains(NotificationConstants.reminderNotificationId(showup.id)) ||
            actualIds.contains(NotificationConstants.deadlineNotificationId(showup.id)) ||
            actualIds.contains(NotificationConstants.hurryUpNotificationId(showup.id));
        if (hasStalePending) {
          await _notificationService.cancelShowupReminder(showup.id);
          cancelledCount++;
        }
      }
    }

    if (rescheduledCount > 0 || cancelledCount > 0) {
      await _analytics.logEvent(
        NotificationsReconciledEvent(rescheduledCount: rescheduledCount, cancelledCount: cancelledCount),
      );
    }
  }

  // Schedules only the specific notification kinds missing from [actualIds]
  // for this desired item — an already-pending id is left untouched, so a
  // repeated reconcile() over unchanged state makes no further calls.
  // Returns how many individual notifications were (re)scheduled.
  Future<int> _applyMissing(PlannedReminder item, Pact pact, Set<int> actualIds) async {
    var count = 0;

    if (!actualIds.contains(NotificationConstants.reminderNotificationId(item.showup.id))) {
      await _notificationService.scheduleShowupReminder(
        showup: item.showup,
        pact: pact,
        titleText: item.reminderTitle,
        bodyText: item.reminderBody,
      );
      count++;
    }

    final deadline = item.deadline;
    if (deadline != null && !actualIds.contains(NotificationConstants.deadlineNotificationId(item.showup.id))) {
      await _notificationService.scheduleDeadlineNotification(
        showup: item.showup,
        titleText: deadline.title,
        bodyText: deadline.body,
      );
      count++;
    }

    final hurryUp = item.hurryUp;
    if (hurryUp != null && !actualIds.contains(NotificationConstants.hurryUpNotificationId(item.showup.id))) {
      await _notificationService.scheduleHurryUpNotification(
        showup: item.showup,
        hurryUpOffset: hurryUp.offset,
        titleText: hurryUp.title,
        bodyText: hurryUp.body,
      );
      count++;
    }

    return count;
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
