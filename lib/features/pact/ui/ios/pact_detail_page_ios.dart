import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:habit_loop/features/pact/domain/pact_detail_state.dart';
import 'package:intl/intl.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class PactDetailPageIos extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;

  const PactDetailPageIos({
    super.key,
    required this.state,
    required this.onStopPact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.pactDetailTitle),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : state.loadError != null
                  ? Center(child: Text(state.loadError.toString()))
                  : _PactDetailContent(
                      state: state,
                      l10n: l10n,
                      onStopPact: onStopPact,
                    ),
        ),
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
    final pact = state.pact!;
    final stats = state.stats!;
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(pact.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: _statusColor(pact.status),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Stats cards
        _SectionHeader(title: 'Stats'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: l10n.statsDone, value: l10n.statsShowups(stats.showupsDone))),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: l10n.statsFailed, value: l10n.statsShowups(stats.showupsFailed))),
          ],
        ),
        if (pact.status == PactStatus.active || stats.showupsRemaining > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard(label: l10n.statsRemaining, value: l10n.statsShowups(stats.showupsRemaining))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: l10n.statsStreak, value: l10n.statsShowups(stats.currentStreak))),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard(label: l10n.statsStreak, value: l10n.statsShowups(stats.currentStreak))),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // Time details
        _SectionHeader(title: 'Timeline'),
        const SizedBox(height: 8),
        _DateRow(label: l10n.pactStartDate, date: pact.startDate),
        const SizedBox(height: 8),
        _DateRow(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          date: pact.endDate,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: 8),
          _InfoRow(label: l10n.daysRemaining(daysLeft)),
        ],

        // Stop reason (if stopped)
        if (pact.status == PactStatus.stopped && pact.stopReason != null) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Stop reason'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(pact.stopReason!),
          ),
        ],

        // Stop pact button
        if (pact.status == PactStatus.active) ...[
          const SizedBox(height: 32),
          CupertinoButton(
            color: CupertinoColors.destructiveRed,
            onPressed: state.isStopping
                ? null
                : () => _showStopDialog(context),
            child: state.isStopping
                ? const CupertinoActivityIndicator()
                : Text(l10n.stopPact),
          ),
        ],
      ],
    );
  }

  Color _statusColor(PactStatus status) {
    return switch (status) {
      PactStatus.active => CupertinoColors.activeBlue,
      PactStatus.stopped => CupertinoColors.destructiveRed,
      PactStatus.completed => CupertinoColors.activeGreen,
    };
  }

  Future<void> _showStopDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.stopPactTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(l10n.stopPactBody),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: reasonController,
              placeholder: l10n.stopPactReasonHint,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
    reasonController.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.systemGrey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            DateFormat.yMd(Localizations.localeOf(context).toString()).format(date),
            style: const TextStyle(color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  const _InfoRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label),
    );
  }
}
