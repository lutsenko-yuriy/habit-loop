import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_status_colors.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';
import 'package:habit_loop/theme/widgets/status_badge.dart';

class PactDetailPageAndroid extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;

  /// Called when the user taps the edit icon button in the AppBar.
  ///
  /// `null` (or hidden) when the pact is not active or not yet loaded.
  final VoidCallback? onEditPact;

  const PactDetailPageAndroid({
    super.key,
    required this.state,
    required this.onStopPact,
    this.onEditPact,
  });

  bool get _isActive => state.pact?.status == PactStatus.active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pactDetailTitle),
        actions: [
          if (_isActive && onEditPact != null)
            IconButton(
              key: const Key('pact-detail-edit-button'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditPact,
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.loadError != null
              ? Center(child: Text(state.loadError.toString()))
              : _PactDetailContent(
                  state: state,
                  l10n: l10n,
                  onStopPact: onStopPact,
                ),
    );
  }
}

class _PactDetailContent extends StatelessWidget {
  final PactDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function(String? reason) onStopPact;

  const _PactDetailContent({
    required this.state,
    required this.l10n,
    required this.onStopPact,
  });

  @override
  Widget build(BuildContext context) {
    final pact = state.pact;
    final stats = state.stats;
    assert(pact != null && stats != null, '_PactDetailContent must only be shown after a successful load');
    if (pact == null || stats == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysLeft = pact.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    final statusText = pactStatusText(l10n, pact.status);
    final statusColor = PactStatusColors.material.forStatus(pact.status);
    final tileColor = theme.colorScheme.surfaceContainerHighest;
    final valueColor = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Habit name + status badge
        Row(
          children: [
            Expanded(
              child: Text(
                pact.habitName,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            StatusBadge(text: statusText, color: statusColor),
          ],
        ),
        const SizedBox(height: 24),

        // Stats cards
        SectionHeader(title: l10n.sectionStats, labelColor: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: l10n.statsDone, value: l10n.statsShowups(stats.showupsDone))),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: l10n.statsFailed, value: l10n.statsShowups(stats.showupsFailed))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (pact.status == PactStatus.active)
              Expanded(child: _StatCard(label: l10n.statsRemaining, value: l10n.statsShowups(stats.showupsRemaining)))
            else if (pact.status == PactStatus.stopped)
              Expanded(child: _StatCard(label: l10n.statsCancelled, value: l10n.statsShowups(stats.showupsRemaining))),
            if (pact.status != PactStatus.completed) const SizedBox(width: 8),
            Expanded(child: _StatCard(label: l10n.statsStreak, value: l10n.statsShowups(stats.currentStreak))),
          ],
        ),
        const SizedBox(height: 24),

        // Time details
        SectionHeader(title: l10n.sectionTimeline, labelColor: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.pactStartDate,
          value: formatLocaleDate(context, pact.startDate),
          valueColor: valueColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
        ),
        const SizedBox(height: 8),
        if (pact.status == PactStatus.stopped && pact.stoppedAt != null) ...[
          DateRowTile(
            label: l10n.pactStoppedDate,
            value: formatLocaleDate(context, pact.stoppedAt!),
            valueColor: valueColor,
            backgroundColor: tileColor,
            cornerRadius: 12,
          ),
          const SizedBox(height: 8),
        ],
        DateRowTile(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          value: formatLocaleDate(context, pact.endDate),
          valueColor: valueColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: 8),
          DateRowTile(
            label: l10n.daysRemaining(daysLeft),
            backgroundColor: tileColor,
            cornerRadius: 12,
          ),
        ],
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.summaryShowupDuration,
          value: l10n.showupDurationMinutes(pact.showupDuration.inMinutes),
          valueColor: valueColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
        ),
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.summaryReminder,
          value: reminderDescription(l10n, pact.reminderOffset),
          valueColor: valueColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
        ),

        // Stop reason (if stopped)
        if (pact.status == PactStatus.stopped && pact.stopReason != null) ...[
          const SizedBox(height: 24),
          SectionHeader(title: l10n.sectionStopReason, labelColor: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(pact.stopReason!),
            ),
          ),
        ],

        // Stop pact button
        if (pact.status == PactStatus.active) ...[
          const SizedBox(height: 32),
          if (state.stopError != null) ...[
            Text(l10n.stopPactError, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: state.isStopping ? null : () => _showStopDialog(context),
            child: state.isStopping
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onError))
                : Text(l10n.stopPact),
          ),
        ],
      ],
    );
  }

  Future<void> _showStopDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.stopPactTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.stopPactBody),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(hintText: l10n.stopPactReasonHint),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.stopPactConfirm),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final reason = reasonController.text.trim();
        await onStopPact(reason.isEmpty ? null : reason);
      }
    } finally {
      reasonController.dispose();
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
