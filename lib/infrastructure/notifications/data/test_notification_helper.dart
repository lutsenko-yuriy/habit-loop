import 'package:flutter/foundation.dart' show debugPrint;
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';

/// Schedules a local notification to fire in 15 seconds with a fake payload.
///
/// Background the app after calling this, wait 15 s, then tap the notification
/// — the console should show `[Notif]` log lines and the showup detail screen
/// should open (showing "showup not found" because the ID is fake, but that
/// confirms the full navigation stack is wired correctly).
///
/// Uses [NotificationService.scheduleShowupReminder] with a fake [Pact] whose
/// `reminderOffset` is [Duration.zero] and a fake [Showup] whose `scheduledAt`
/// is 15 s from now, so the notification fires immediately at `scheduledAt`
/// without any offset subtraction. This goes through the same code path as
/// production scheduling and avoids importing plugin internals directly.
///
/// Only referenced from debug/profile-mode UI — not compiled into release
/// builds via tree-shaking once the call sites are guarded by [kDebugMode] /
/// [kProfileMode].
Future<void> scheduleTestNotification(NotificationService notificationService) async {
  final now = DateTime.now();
  // reminderOffset = Duration.zero means fireAt = scheduledAt (no subtraction).
  final fireAt = now.add(const Duration(seconds: 15));

  final fakeShowup = Showup(
    id: 'test-showup-id',
    pactId: 'test-pact-id',
    scheduledAt: fireAt,
    duration: const Duration(minutes: 30),
    status: ShowupStatus.pending,
  );

  final fakePact = Pact(
    id: 'test-pact-id',
    habitName: 'Test Habit',
    startDate: now,
    endDate: now.add(const Duration(days: 180)),
    showupDuration: const Duration(minutes: 30),
    schedule: DailySchedule(timeOfDay: Duration(hours: now.hour, minutes: now.minute)),
    status: PactStatus.active,
    reminderOffset: Duration.zero,
  );

  await notificationService.scheduleShowupReminder(
    showup: fakeShowup,
    pact: fakePact,
    titleText: '🔔 Test notification',
    bodyText: 'Tap me — navigation should open showup detail',
  );
  debugPrint('[TestNotif] scheduled for $fireAt — background the app and tap the banner in 15 s');
}
