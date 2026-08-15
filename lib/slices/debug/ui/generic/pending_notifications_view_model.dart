import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notification_row.dart';

/// Resolves the OS's currently-pending notifications into display rows
/// (HAB-228). [PendingNotificationInfo] carries no fire time — the OS
/// pending-notifications query doesn't return one — so it's recomputed here
/// from the payload's `showupId`: reminder-range ids use
/// `scheduledAt - reminderOffset`, deadline-range ids use
/// `scheduledAt + duration`. Any failure along that path (missing/malformed
/// payload, deleted showup/pact, cleared reminderOffset) just leaves
/// [PendingNotificationRow.fireAt] null — the row is still shown.
class PendingNotificationsViewModel extends AutoDisposeAsyncNotifier<List<PendingNotificationRow>> {
  @override
  Future<List<PendingNotificationRow>> build() async {
    final notificationService = ref.read(notificationServiceProvider);
    final showupRepository = ref.read(showupRepositoryProvider);
    final pactRepository = ref.read(pactRepositoryProvider);

    final pending = await notificationService.getPendingNotifications();
    final rows = <PendingNotificationRow>[];

    for (final notification in pending) {
      DateTime? fireAt;
      final showupId = _decodeShowupId(notification.payload);
      if (showupId != null) {
        final showup = await showupRepository.getShowupById(showupId);
        if (showup != null) {
          final isDeadline = notification.id >= NotificationConstants.deadlineRangeStart;
          if (isDeadline) {
            fireAt = showup.scheduledAt.add(showup.duration);
          } else {
            final pact = await pactRepository.getPactById(showup.pactId);
            if (pact?.reminderOffset != null) {
              fireAt = showup.scheduledAt.subtract(pact!.reminderOffset!);
            }
          }
        }
      }
      rows.add(PendingNotificationRow(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        fireAt: fireAt,
      ));
    }

    rows.sort((a, b) {
      if (a.fireAt == null && b.fireAt == null) return 0;
      if (a.fireAt == null) return 1;
      if (b.fireAt == null) return -1;
      return a.fireAt!.compareTo(b.fireAt!);
    });
    return rows;
  }

  String? _decodeShowupId(String? payload) {
    if (payload == null) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['showupId'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final pendingNotificationsViewModelProvider =
    AutoDisposeAsyncNotifierProvider<PendingNotificationsViewModel, List<PendingNotificationRow>>(
  PendingNotificationsViewModel.new,
);
