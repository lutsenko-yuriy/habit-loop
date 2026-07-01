import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';

/// Schedules a local notification in 15 seconds using the nearest real pending
/// showup from the active pacts.
///
/// Background the app after calling this, wait 15 s, then tap the notification
/// — the app should navigate to the real showup detail screen, verifying that
/// notifications are enabled, arrive, are tappable, and deep-link navigation
/// is wired correctly.
///
/// If no upcoming pending showup exists, logs a warning and returns early.
///
/// Only referenced from debug/profile-mode UI — not compiled into release
/// builds via tree-shaking once the call sites are guarded by [kDebugMode] /
/// [kProfileMode].
Future<void> scheduleTestNotification(
  NotificationService notificationService,
  PactRepository pactRepository,
  ShowupRepository showupRepository,
) async {
  assert(!kReleaseMode, 'scheduleTestNotification must not be called in release builds');
  if (kReleaseMode) return;

  final now = DateTime.now();

  // Find the nearest upcoming pending showup across all active pacts.
  final activePacts = await pactRepository.getActivePacts();
  Showup? nearest;
  Pact? nearestPact;

  for (final pact in activePacts) {
    final showups = await showupRepository.getShowupsForPact(pact.id);
    for (final showup in showups) {
      if (showup.status != ShowupStatus.pending) continue;
      if (!showup.scheduledAt.isAfter(now)) continue;
      if (nearest == null || showup.scheduledAt.isBefore(nearest.scheduledAt)) {
        nearest = showup;
        nearestPact = pact;
      }
    }
  }

  if (nearest == null || nearestPact == null) {
    debugPrint('[TestNotif] no upcoming pending showup — create an active pact with future showups first');
    return;
  }

  final fireAt = now.add(const Duration(seconds: 15));

  // Keep the real showup id so navigation deep-links to the actual showup.
  // Override scheduledAt to fireAt and use reminderOffset=Duration.zero so the
  // notification fires in exactly 15 s (fireAt = scheduledAt - Duration.zero).
  final testShowup = Showup(
    id: nearest.id,
    pactId: nearest.pactId,
    scheduledAt: fireAt,
    duration: nearest.duration,
    status: nearest.status,
    note: nearest.note,
    redeemable: nearest.redeemable,
  );
  final testPact = nearestPact.copyWith(reminderOffset: Duration.zero);

  // Cancel any existing reminder for this showup before overriding with the
  // 15-second test fire so we don't leave a stale duplicate.
  await notificationService.cancelShowupReminder(nearest.id);
  await notificationService.scheduleShowupReminder(
    showup: testShowup,
    pact: testPact,
    titleText: '🔔 Test — ${nearestPact.habitName}',
    bodyText: 'Tap me — should open the real showup detail',
  );

  debugPrint(
    '[TestNotif] scheduled for $fireAt using real showup ${nearest.id} '
    '(${nearestPact.habitName}) — background the app and tap the banner in 15 s',
  );
}
