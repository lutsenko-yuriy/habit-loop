import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notification_row.dart';
import 'package:habit_loop/slices/debug/ui/generic/pending_notifications_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Read-only debug viewer listing every notification currently pending with
/// the OS, sorted soonest-first (HAB-228). See [PendingNotificationsViewModel]
/// for how each row's fire time is resolved.
class PendingNotificationsPageAndroid extends ConsumerWidget {
  const PendingNotificationsPageAndroid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(pendingNotificationsViewModelProvider);

    return Scaffold(
      appBar: AppBar(scrolledUnderElevation: 0, title: const Text('Pending Notifications')),
      body: switch (rowsAsync) {
        AsyncData(:final value) => value.isEmpty
            ? const Center(
                key: Key('pending-notifications-empty'),
                child: Text('No pending notifications'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.s16),
                itemCount: value.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                itemBuilder: (context, index) => _PendingNotificationRowTile(row: value[index]),
              ),
        AsyncError() => const Center(child: Text('Could not load pending notifications')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PendingNotificationRowTile extends StatelessWidget {
  const _PendingNotificationRowTile({required this.row});

  final PendingNotificationRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('pending-notification-${row.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.title ?? '(no title)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.s2),
            Text(row.body ?? '(no body)', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.s6),
            Text(
              row.fireAt == null ? 'No scheduled time' : '${formatShowupDate(row.fireAt!)} ${formatShowupTime(context, row.fireAt!)}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
