import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';

/// Cancels and re-schedules every active pact's pending reminders — the OS
/// notification payload can't be edited in place, only replaced. Shared by
/// the language switch (HAB-157) and display-name change (HAB-232 WU7) flows.
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
