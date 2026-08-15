import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notification_row.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notifications_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Read-only debug viewer listing every notification currently pending with
/// the OS, sorted soonest-first (HAB-228). See [PendingNotificationsViewModel]
/// for how each row's fire time is resolved.
class PendingNotificationsPageIos extends ConsumerWidget {
  const PendingNotificationsPageIos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(pendingNotificationsViewModelProvider);

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: const Text('Pending Notifications'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // iOS's pendingNotificationRequests() is believed to only return
            // notifications scheduled in the current app session (see the same
            // caveat on cancelAllRemindersForPact's fallback path in
            // flutter_local_notification_service.dart) — an empty list here
            // isn't proof nothing is actually pending with the OS.
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s0),
              child: Text(
                'iOS may only report notifications scheduled since this app launch — not proof nothing is pending.',
                key: Key('ios-session-only-caveat'),
                style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
              ),
            ),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: switch (rowsAsync) {
                  AsyncData(:final value) => value.isEmpty
                      ? const Center(
                          key: Key('pending-notifications-empty'),
                          child: Text('No pending notifications', style: TextStyle(color: CupertinoColors.systemGrey)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          itemCount: value.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                          itemBuilder: (context, index) => _PendingNotificationRowTile(row: value[index]),
                        ),
                  AsyncError() => const Center(
                      child: Text(
                        'Could not load pending notifications',
                        style: TextStyle(color: CupertinoColors.systemRed),
                      ),
                    ),
                  _ => const Center(child: CupertinoActivityIndicator()),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingNotificationRowTile extends StatelessWidget {
  const _PendingNotificationRowTile({required this.row});

  final PendingNotificationRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('pending-notification-${row.id}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.title ?? '(no title)', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.s2),
          Text(row.body ?? '(no body)', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: AppSpacing.s6),
          Text(
            row.fireAt == null
                ? 'No scheduled time (${unresolvedFireTimeReasonLabel(row.unresolvedReason)}) — id ${row.id}'
                : '${formatShowupDate(row.fireAt!)} ${formatShowupTime(context, row.fireAt!)}',
            style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }
}
