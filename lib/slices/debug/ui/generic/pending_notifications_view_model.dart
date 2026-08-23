import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notification_row.dart';

// HAB-246: same RC key ReminderSchedulingService reads to compute the
// hurry-up fire time.
const _kHurryUpTimeInMinutes = 'hurry_up_time_in_minutes';

/// Resolves the OS's currently-pending notifications into display rows
/// (HAB-228). [PendingNotificationInfo] carries no fire time — the OS
/// pending-notifications query doesn't return one — so it's recomputed here
/// from the payload's `showupId`: reminder-range ids use
/// `scheduledAt - reminderOffset`, deadline-range ids use
/// `scheduledAt + duration`, hurry-up-range ids use
/// `scheduledAt + duration - hurryUpTime` (HAB-246). Any failure along that
/// path (missing/malformed payload, deleted showup/pact, cleared
/// reminderOffset) just leaves [PendingNotificationRow.fireAt] null with the
/// reason recorded — the row is still shown.
class PendingNotificationsViewModel extends AutoDisposeAsyncNotifier<List<PendingNotificationRow>> {
  @override
  Future<List<PendingNotificationRow>> build() async {
    final notificationService = ref.read(notificationServiceProvider);
    final showupRepository = ref.read(showupRepositoryProvider);
    final pactRepository = ref.read(pactRepositoryProvider);
    final remoteConfig = ref.read(remoteConfigServiceProvider);

    final pending = await notificationService.getPendingNotifications();

    // Memoized across rows — a reminder + deadline pair share a showup, and
    // many showups share a pact, so this keeps a large pending list to one
    // repository read per distinct showup/pact rather than per row.
    final showupCache = <String, Showup?>{};
    final pactCache = <String, Pact?>{};

    // Sourced from intRanges rather than a hardcoded literal so this and
    // ReminderSchedulingService's own clamp can't drift apart (HAB-246 audit).
    final hurryUpRange = RemoteConfigDefaults.intRanges[_kHurryUpTimeInMinutes]!;
    final hurryUpTime = Duration(
      minutes: remoteConfig.getInt(_kHurryUpTimeInMinutes).clamp(hurryUpRange.min, hurryUpRange.max),
    );

    final rows = <PendingNotificationRow>[];
    for (final notification in pending) {
      rows.add(
        await _resolveRow(notification, showupRepository, pactRepository, showupCache, pactCache, hurryUpTime),
      );
    }

    rows.sort((a, b) {
      if (a.fireAt == null && b.fireAt == null) return a.id.compareTo(b.id);
      if (a.fireAt == null) return 1;
      if (b.fireAt == null) return -1;
      final byTime = a.fireAt!.compareTo(b.fireAt!);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return rows;
  }

  Future<PendingNotificationRow> _resolveRow(
    PendingNotificationInfo notification,
    ShowupRepository showupRepository,
    PactRepository pactRepository,
    Map<String, Showup?> showupCache,
    Map<String, Pact?> pactCache,
    Duration hurryUpTime,
  ) async {
    PendingNotificationRow row({DateTime? fireAt, UnresolvedFireTimeReason reason = UnresolvedFireTimeReason.none}) =>
        PendingNotificationRow(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          fireAt: fireAt,
          unresolvedReason: reason,
        );

    final showupId = _decodeShowupId(notification.payload);
    if (showupId == null) {
      final malformed = notification.payload != null;
      return row(
        reason: malformed ? UnresolvedFireTimeReason.malformedPayload : UnresolvedFireTimeReason.missingPayload,
      );
    }

    final showup =
        showupCache.containsKey(showupId) ? showupCache[showupId] : await showupRepository.getShowupById(showupId);
    showupCache[showupId] = showup;
    if (showup == null) {
      return row(reason: UnresolvedFireTimeReason.showupNotFound);
    }

    if (NotificationConstants.isHurryUpNotificationId(notification.id)) {
      return row(fireAt: showup.scheduledAt.add(showup.duration).subtract(hurryUpTime));
    }

    final isDeadline = notification.id >= NotificationConstants.deadlineRangeStart;
    if (isDeadline) {
      return row(fireAt: showup.scheduledAt.add(showup.duration));
    }

    final pactId = showup.pactId;
    final pact = pactCache.containsKey(pactId) ? pactCache[pactId] : await pactRepository.getPactById(pactId);
    pactCache[pactId] = pact;
    if (pact == null) {
      return row(reason: UnresolvedFireTimeReason.pactNotFound);
    }
    if (pact.reminderOffset == null) {
      return row(reason: UnresolvedFireTimeReason.noReminderOffset);
    }
    return row(fireAt: showup.scheduledAt.subtract(pact.reminderOffset!));
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
