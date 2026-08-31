import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';

/// Cancels and re-schedules every active pact's pending reminders — for any
/// change that invalidates already-scheduled notification text, since the OS
/// payload can't be edited in place, only cancelled and replaced. Originally
/// written for an in-app language switch (HAB-157); a display name
/// change/clear needs the exact same treatment (HAB-232 WU7 audit finding —
/// `NotificationReconciliationService` can't heal this on its own, since its
/// diff is keyed by notification id, not by text).
Future<void> rescheduleAllPendingReminders(WidgetRef ref) async {
  final queryService = ref.read(dashboardQueryServiceProvider);
  final schedulingService = ref.read(reminderSchedulingServiceProvider);
  final pactBreakRepository = ref.read(pactBreakRepositoryProvider);

  final activePacts = await queryService.getActivePacts();
  for (final pact in activePacts) {
    if (pact.reminderOffset == null) continue;

    final showups = await queryService.getShowupsForPact(pact.id);
    final showupIds = showups.map((s) => s.id).toList();
    // breaks: threaded through so the reschedule doesn't resurrect a
    // suppressed on-break reminder (HAB-215 note) or drop welcome-back text
    // (HAB-227) for every active pact this touches.
    final breaks = await pactBreakRepository.getBreaksForPact(pact.id);

    await schedulingService.cancelAllRemindersForPact(pact.id, showupIds: showupIds);
    unawaited(schedulingService.scheduleRemindersForShowups(pact: pact, showups: showups, breaks: breaks));
  }
}
