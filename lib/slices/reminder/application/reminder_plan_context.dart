import 'package:flutter/foundation.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

// EXP-001: notification text urgency experiment.
const _kNotificationTextVariant = 'notification_text_variant';

// EXP-002: post-deadline notification behaviour (Android only).
const _kPostDeadlineNotificationBehavior = 'post_deadline_notification_behavior';

// HAB-227: kill-switch for the break-over "welcome back" reminder text.
const _kBreakWelcomeBackEnabled = 'break_welcome_back_notification_enabled';

// HAB-246: kill-switch + bounded offset for the hurry-up reminder notification.
const _kHurryUpEnabled = 'hurry_up_notification_enabled';
const _kHurryUpTimeInMinutes = 'hurry_up_time_in_minutes';

/// The remote-config-derived half of [ReminderPlanner]'s inputs — everything
/// [ReminderPlanner.plan] needs besides pact/showups/breaks/now/l10n/isIOS.
/// [resolve] is the single reading of remote config, so a second caller
/// (NotificationReconciliationService, HAB-254 WU2) shares this exact
/// resolution path instead of re-reading the same keys and risking drift —
/// a stale clamp or a kill-switch read a different way would otherwise turn
/// into a permanent desired-vs-actual mismatch the reconciler "fixes" every
/// run (audit finding, PR #410).
@immutable
class ReminderPlanContext {
  const ReminderPlanContext({
    required this.textVariant,
    required this.scheduleDeadline,
    required this.hurryUpEnabled,
    required this.hurryUpTime,
    required this.welcomeBackEnabled,
    this.displayName,
  });

  final String textVariant;
  final bool scheduleDeadline;
  final bool hurryUpEnabled;
  final Duration hurryUpTime;
  final bool welcomeBackEnabled;

  // Personalizes every notification's title when non-null (HAB-232 WU7).
  // Supplied by the caller, not read here — [resolve] stays a pure
  // Remote-Config read; the name comes from personalizedNameProvider instead.
  final String? displayName;

  // scheduleDeadline: iOS always schedules it; Android only when the RC
  // behavior is 'encourage' (EXP-002). hurryUpTime is clamped — an
  // unset/blank console value returns 0, which would make every showup
  // eligible and fire right at the deadline (HAB-246 audit). Sourced from
  // intRanges rather than a hardcoded literal so this and the debug
  // pending-notifications screen can't drift apart.
  factory ReminderPlanContext.resolve({
    required RemoteConfigService remoteConfig,
    required bool isIOS,
    String? displayName,
  }) {
    final postDeadlineBehavior = remoteConfig.getString(_kPostDeadlineNotificationBehavior);
    final hurryUpRange = RemoteConfigDefaults.intRanges[_kHurryUpTimeInMinutes]!;
    return ReminderPlanContext(
      textVariant: remoteConfig.getString(_kNotificationTextVariant),
      scheduleDeadline: isIOS || postDeadlineBehavior == 'encourage',
      hurryUpEnabled: remoteConfig.getBool(_kHurryUpEnabled),
      hurryUpTime: Duration(
        minutes: remoteConfig.getInt(_kHurryUpTimeInMinutes).clamp(hurryUpRange.min, hurryUpRange.max),
      ),
      welcomeBackEnabled: remoteConfig.getBool(_kBreakWelcomeBackEnabled),
      displayName: displayName,
    );
  }
}
