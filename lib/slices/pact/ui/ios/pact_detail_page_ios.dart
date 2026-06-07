import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
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

class PactDetailPageIos extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;

  /// Called when the user taps the pencil edit button in the nav bar.
  ///
  /// `null` (or hidden) when the pact is not active or not yet loaded.
  final VoidCallback? onEditPact;

  const PactDetailPageIos({
    super.key,
    required this.state,
    required this.onStopPact,
    this.onEditPact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final isActive = state.pact?.status == PactStatus.active;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.pactDetailTitle),
        trailing: isActive && onEditPact != null
            ? CupertinoButton(
                key: const Key('pact-detail-edit-button'),
                padding: EdgeInsets.zero,
                onPressed: onEditPact,
                child: const Icon(CupertinoIcons.pencil),
              )
            : null,
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
    final pact = state.pact;
    final stats = state.stats;
    assert(pact != null && stats != null, '_PactDetailContent must only be shown after a successful load');
    if (pact == null || stats == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final daysLeft = pact.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    final statusText = pactStatusText(l10n, pact.status);
    final statusColor = PactStatusColors.cupertino(context).forStatus(pact.status);
    final fill = CupertinoColors.tertiarySystemFill.resolveFrom(context);

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
            StatusBadge(text: statusText, color: statusColor),
          ],
        ),
        const SizedBox(height: 24),

        // Stats cards
        SectionHeader(title: l10n.sectionStats, labelColor: CupertinoColors.systemGrey),
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
        SectionHeader(title: l10n.sectionTimeline, labelColor: CupertinoColors.systemGrey),
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.pactStartDate,
          value: formatLocaleDate(context, pact.startDate),
          valueColor: CupertinoColors.systemGrey,
          backgroundColor: fill,
        ),
        const SizedBox(height: 8),
        if (pact.status == PactStatus.stopped && pact.stoppedAt != null) ...[
          DateRowTile(
            label: l10n.pactStoppedDate,
            value: formatLocaleDate(context, pact.stoppedAt!),
            valueColor: CupertinoColors.systemGrey,
            backgroundColor: fill,
          ),
          const SizedBox(height: 8),
        ],
        DateRowTile(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          value: formatLocaleDate(context, pact.endDate),
          valueColor: CupertinoColors.systemGrey,
          backgroundColor: fill,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: 8),
          DateRowTile(label: l10n.daysRemaining(daysLeft), backgroundColor: fill),
        ],
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.summaryShowupDuration,
          value: l10n.showupDurationMinutes(pact.showupDuration.inMinutes),
          valueColor: CupertinoColors.systemGrey,
          backgroundColor: fill,
        ),
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.summaryReminder,
          value: reminderDescription(l10n, pact.reminderOffset),
          valueColor: CupertinoColors.systemGrey,
          backgroundColor: fill,
        ),

        // Stop reason (if stopped)
        if (pact.status == PactStatus.stopped && pact.stopReason != null) ...[
          const SizedBox(height: 24),
          SectionHeader(title: l10n.sectionStopReason, labelColor: CupertinoColors.systemGrey),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(pact.stopReason!),
          ),
        ],

        // Stop pact button
        if (pact.status == PactStatus.active) ...[
          const SizedBox(height: 32),
          if (state.stopError != null) ...[
            Text(
              l10n.stopPactError,
              style: const TextStyle(color: CupertinoColors.destructiveRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          CupertinoButton(
            onPressed: state.isStopping ? null : () => _showStopDialog(context),
            child: state.isStopping
                ? const CupertinoActivityIndicator()
                : Text(
                    l10n.stopPact,
                    style: const TextStyle(color: CupertinoColors.destructiveRed),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _showStopDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    try {
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
