import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_detail_state.dart';
import 'package:intl/intl.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

class PactDetailPageAndroid extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;

  const PactDetailPageAndroid({
    super.key,
    required this.state,
    required this.onStopPact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pactDetailTitle)),
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
    assert(pact != null && stats != null,
        '_PactDetailContent must only be shown after a successful load');
    if (pact == null || stats == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysLeft = pact.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    final statusText = switch (pact.status) {
      PactStatus.active => l10n.pactStatusActive,
      PactStatus.stopped => l10n.pactStatusStopped,
      PactStatus.completed => l10n.pactStatusCompleted,
    };

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
            Chip(
              label: Text(statusText),
              backgroundColor: _statusColor(pact.status).withValues(alpha: 0.15),
              labelStyle: TextStyle(color: _statusColor(pact.status), fontWeight: FontWeight.w600),
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Stats cards
        Text(l10n.sectionStats.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.5)),
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
        Text(l10n.sectionTimeline.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _DateRow(label: l10n.pactStartDate, date: pact.startDate),
        const SizedBox(height: 8),
        _DateRow(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          date: pact.endDate,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(l10n.daysRemaining(daysLeft)),
            ),
          ),
        ],

        // Stop reason (if stopped)
        if (pact.status == PactStatus.stopped && pact.stopReason != null) ...[
          const SizedBox(height: 24),
          Text(l10n.sectionStopReason.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.5)),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: state.isStopping ? null : () => _showStopDialog(context),
            child: state.isStopping
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.stopPact),
          ),
        ],
      ],
    );
  }

  Color _statusColor(PactStatus status) {
    return switch (status) {
      PactStatus.active => HabitLoopColors.primary,
      PactStatus.stopped => HabitLoopColors.danger,
      PactStatus.completed => HabitLoopColors.success,
    };
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  const _DateRow({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMd(Localizations.localeOf(context).toString()).format(date),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
