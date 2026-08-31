import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/planned_reminder.dart';
import 'package:habit_loop/slices/reminder/application/reminder_locale_resolver.dart';
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
/// showup that is genuinely no longer eligible for any notification (done,
/// failed, or now covered by a break) but still has one pending.
///
/// A showup simply absent from the desired set because its reminder fire
/// time already passed — i.e. it is in progress — is deliberately **not**
/// touched: its deadline/hurry-up notifications are still legitimately
/// pending, and [NotificationService.cancelShowupReminder] cancels all three
/// ids for a showup at once, so treating "not desired right now" as "cancel
/// everything" would silently kill notifications the showup still needs
/// (audit finding, PR #411).
///
/// **v1 scope guards** (see `docs/knowledge/notes/HAB-254.md`): diffs by
/// notification *id* only, not title/body — a showup whose desired copy
/// changed (e.g. a stale locale) without touching its on/off-break status
/// keeps stale text until it is otherwise rescheduled (HAB-229's/the
/// language-picker bug's follow-up). Cancellation only ever targets ids
/// attributable to a showup this pact still tracks — an orphaned id from a
/// deleted/reseeded showup is left alone (HAB-229, tracked separately).
/// Stopped pacts and pacts whose `reminderOffset` was cleared are excluded
/// from the whole pass (same as `getActivePacts`/one-shot scheduling), so
/// any stale notification belonging to one is unreachable here too — those
/// paths already cancel explicitly on the mutation that stops them.
///
/// **iOS's cold-start reliability is still an open question** (see the
/// Research-WU findings in `docs/knowledge/notes/HAB-254.md`): this
/// repo's own `flutter_local_notification_service.dart` notes that
/// `getPendingNotifications()` may only reflect the current session on iOS.
/// If a device check in WU3 confirms that, `actualIds` reads empty after a
/// cold start on iOS — scheduling stays safe either way (idempotent
/// overwrite, same cost as the pre-HAB-254 one-shot scheduler), but
/// cancellation would silently stop firing until a warm relaunch. WU3's
/// `[human]` on-device verification item is the gate for trusting this
/// mechanism's cancellation side on iOS; this WU does not attempt to guess
/// the fix ahead of that data.
///
/// No trigger is wired to this yet — that is HAB-254 WU3's job
/// (`AppLifecycleReconciler`, `SyncService.pullCompleted`).
final class NotificationReconciliationService {
  // [displayName] is the caller's resolved personalizedNameProvider value
  // (HAB-232 WU7) — read at the composition root, not here, so this class
  // stays free of a Riverpod dependency. Must be kept in sync with whatever
  // ReminderSchedulingService is given, or the reconciler sees a permanent
  // desired-vs-actual mismatch and reschedules every run (same pitfall as
  // ReminderPlanContext.resolve's other inputs — see its doc comment).
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
    String? displayName,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _pactBreakRepository = pactBreakRepository,
        _notificationService = notificationService,
        _remoteConfig = remoteConfig,
        _analytics = analytics,
        _localePreference = localePreference,
        _isIOS = isIOS,
        _systemLocale = systemLocale,
        _displayName = displayName;

  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final PactBreakRepository _pactBreakRepository;
  final NotificationService _notificationService;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final LocalePreferenceService _localePreference;
  final bool _isIOS;
  final Locale _systemLocale;
  final String? _displayName;

  // [now] is injectable for tests.
  Future<void> reconcile({DateTime? now}) async {
    if (!_remoteConfig.getBool(_kReconciliationEnabled)) return;

    final activePacts = await _pactRepository.getActivePacts();
    final remindablePacts = activePacts.where((p) => p.reminderOffset != null).toList();
    if (remindablePacts.isEmpty) return;

    final effectiveNow = now ?? DateTime.now();
    final l10n = await ReminderLocaleResolver.resolve(
      localePreference: _localePreference,
      systemLocale: _systemLocale,
    );
    final context = ReminderPlanContext.resolve(remoteConfig: _remoteConfig, isIOS: _isIOS, displayName: _displayName);
    final actualIds = (await _notificationService.getPendingNotifications()).map((n) => n.id).toSet();

    var rescheduledShowupsCount = 0;
    var cancelledShowupsCount = 0;
    // Shared across pacts so a multi-pact pass can't claim N independent
    // 64-notification grants against one shared OS-level cap on iOS — see
    // ReminderPlanner.plan's budgetCeiling doc comment.
    var iosBudgetRemaining = ReminderPlanner.iosMaxPendingNotifications;

    for (final pact in remindablePacts) {
      // Isolates one pact's repository failure from the rest of the pass —
      // repositories carry no no-throw contract, unlike NotificationService
      // (audit finding, PR #411).
      try {
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
          budgetCeiling: iosBudgetRemaining,
        );
        final desiredShowupIds = plan.map((item) => item.showup.id).toSet();

        if (_isIOS) {
          final spent = plan.fold<int>(
            0,
            (sum, item) => sum + 1 + (item.deadline != null ? 1 : 0) + (item.hurryUp != null ? 1 : 0),
          );
          iosBudgetRemaining = (iosBudgetRemaining - spent).clamp(0, ReminderPlanner.iosMaxPendingNotifications);
        }

        for (final item in plan) {
          if (await _applyMissing(item, pact, actualIds)) rescheduledShowupsCount++;
        }

        for (final showup in showups) {
          if (desiredShowupIds.contains(showup.id)) continue;
          // "Not desired" also covers a showup simply in progress (its
          // reminder fire time passed but its deadline/hurry-up are still
          // pending) — only cancel for the cases that mean it is genuinely
          // no longer eligible for any notification at all.
          final genuinelyUndesired =
              showup.status != ShowupStatus.pending || BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks);
          if (!genuinelyUndesired) continue;

          final hasStalePending = actualIds.contains(NotificationConstants.reminderNotificationId(showup.id)) ||
              actualIds.contains(NotificationConstants.deadlineNotificationId(showup.id)) ||
              actualIds.contains(NotificationConstants.hurryUpNotificationId(showup.id));
          if (hasStalePending) {
            await _notificationService.cancelShowupReminder(showup.id);
            cancelledShowupsCount++;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (rescheduledShowupsCount > 0 || cancelledShowupsCount > 0) {
      await _analytics.logEvent(
        NotificationsReconciledEvent(
          rescheduledShowupsCount: rescheduledShowupsCount,
          cancelledShowupsCount: cancelledShowupsCount,
        ),
      );
    }
  }

  // Schedules only the specific notification kinds missing from [actualIds]
  // for this desired item — an already-pending id is left untouched, so a
  // repeated reconcile() over unchanged state makes no further calls.
  // Returns whether anything was (re)scheduled for this showup.
  Future<bool> _applyMissing(PlannedReminder item, Pact pact, Set<int> actualIds) async {
    var scheduled = false;

    if (!actualIds.contains(NotificationConstants.reminderNotificationId(item.showup.id))) {
      await _notificationService.scheduleShowupReminder(
        showup: item.showup,
        pact: pact,
        titleText: item.reminderTitle,
        bodyText: item.reminderBody,
      );
      scheduled = true;
    }

    final deadline = item.deadline;
    if (deadline != null && !actualIds.contains(NotificationConstants.deadlineNotificationId(item.showup.id))) {
      await _notificationService.scheduleDeadlineNotification(
        showup: item.showup,
        titleText: deadline.title,
        bodyText: deadline.body,
      );
      scheduled = true;
    }

    final hurryUp = item.hurryUp;
    if (hurryUp != null && !actualIds.contains(NotificationConstants.hurryUpNotificationId(item.showup.id))) {
      await _notificationService.scheduleHurryUpNotification(
        showup: item.showup,
        hurryUpOffset: hurryUp.offset,
        titleText: hurryUp.title,
        bodyText: hurryUp.body,
      );
      scheduled = true;
    }

    return scheduled;
  }
}
