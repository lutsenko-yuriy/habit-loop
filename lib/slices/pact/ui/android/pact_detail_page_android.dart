import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

import 'package:habit_loop/slices/pact/ui/generic/break_banner.dart';
import 'package:habit_loop/slices/pact/ui/generic/chain_navigation_stripe.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_note_section.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_status_colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';
import 'package:habit_loop/theme/widgets/status_badge.dart';

class PactDetailPageAndroid extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function(bool archive) onArchivePact;

  /// Called when the user taps the edit icon button in the AppBar.
  ///
  /// `null` (or hidden) when the pact is not active or not yet loaded.
  final VoidCallback? onEditPact;

  /// Whether the pact timeline feature is enabled via Remote Config.
  final bool pactTimelineEnabled;

  /// Called when the user taps the "View Timeline" button.
  ///
  /// `null` hides the button regardless of [pactTimelineEnabled].
  final VoidCallback? onOpenTimeline;

  /// Called when the user taps "Take a break" (HAB-195).
  ///
  /// `null` hides the button — the pact is not active, the feature toggle is
  /// off, or a break already blocks starting a new one.
  final VoidCallback? onStartBreak;

  /// Called when the user confirms "Resume pact" on the active-break banner
  /// (HAB-195 WU5.2).
  final Future<void> Function()? onStopBreak;

  /// Whether the pact-chaining feature is enabled via Remote Config (HAB-202).
  final bool pactChainingEnabled;

  /// Called when the user taps the "Previous Pact" link.
  ///
  /// `null` hides the link — no predecessor, or the feature toggle is off.
  final VoidCallback? onOpenPreviousPact;

  /// Called when the user taps the "Next Pact" link.
  ///
  /// `null` hides the link — no successor, or the feature toggle is off.
  final VoidCallback? onOpenNextPact;

  /// Called when the user taps "Adjust and start again" (HAB-202).
  ///
  /// `null` hides the button — the pact is active, already has a successor,
  /// or the feature toggle is off.
  final VoidCallback? onAdjustAndStartAgain;

  /// Controller for the content `ListView`, owned by [PactDetailScreen]
  /// (HAB-202) so it can reset scroll position back to the top after
  /// returning from the "Adjust and start again" wizard — otherwise a
  /// newly-relevant "Next Pact" link at the top of the list can stay
  /// scrolled out of view. `null` in tests that don't exercise this.
  final ScrollController? scrollController;

  /// Slide direction for the current chain-link transition (HAB-206 WU3).
  final SlideDirection? chainNavigationDirection;

  /// Outgoing pact's state while a chain-link transition is in flight
  /// (HAB-206 WU3); each animated value diffs itself against this.
  final PactDetailState? previousState;

  /// Pact id [PactDetailScreen] was originally opened with (HAB-206 WU3) —
  /// stable across in-place chain-link swaps, unlike [state]'s own pact id.
  /// Keys the content `ListView` so its subtree survives a swap instead of
  /// being rebuilt (which would pop un-animated content like the notes
  /// section instead of letting it update in place). Falls back to the
  /// current pact's id for callers that don't exercise chain navigation.
  final String? originalPactId;

  const PactDetailPageAndroid({
    super.key,
    required this.state,
    required this.onStopPact,
    required this.onSaveNote,
    required this.onArchivePact,
    this.onEditPact,
    this.pactTimelineEnabled = false,
    this.onOpenTimeline,
    this.onStartBreak,
    this.onStopBreak,
    this.pactChainingEnabled = false,
    this.onOpenPreviousPact,
    this.onOpenNextPact,
    this.onAdjustAndStartAgain,
    this.scrollController,
    this.chainNavigationDirection,
    this.previousState,
    this.originalPactId,
  });

  bool get _isActive => state.pact?.status == PactStatus.active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
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
      body: Column(
        children: [
          Container(height: 0.5, color: Theme.of(context).dividerColor),
          Expanded(
            // Shows the outgoing pact's own content instead of a spinner
            // while a chain-link reload is in flight (HAB-206 WU3) —
            // previousState is only ever set for that case.
            child: (state.isLoading && previousState?.pact == null)
                ? const Center(child: CircularProgressIndicator())
                : state.loadError != null
                    ? Center(child: Text(state.loadError.toString()))
                    : _PactDetailContent(
                        state: state.isLoading ? previousState! : state,
                        l10n: l10n,
                        onStopPact: onStopPact,
                        onSaveNote: onSaveNote,
                        onArchivePact: onArchivePact,
                        pactTimelineEnabled: pactTimelineEnabled,
                        onOpenTimeline: onOpenTimeline,
                        onStartBreak: onStartBreak,
                        onStopBreak: onStopBreak,
                        pactChainingEnabled: pactChainingEnabled,
                        onOpenPreviousPact: onOpenPreviousPact,
                        onOpenNextPact: onOpenNextPact,
                        onAdjustAndStartAgain: onAdjustAndStartAgain,
                        scrollController: scrollController,
                        chainNavigationDirection: chainNavigationDirection,
                        previousState: previousState,
                        originalPactId: originalPactId ?? state.pact?.id ?? previousState?.pact?.id,
                      ),
          ),
          // Invisible marker exposing the currently-shown pact id (HAB-206
          // WU3) — the ListView's own key is pinned to originalPactId now, so
          // scenarios read this instead (see pact_chain_test.dart).
          if (state.pact != null) SizedBox.shrink(key: ValueKey('pact-detail-current-pact-id-${state.pact!.id}')),
        ],
      ),
    );
  }
}

class _PactDetailContent extends StatelessWidget {
  final PactDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function(String? reason) onStopPact;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function(bool archive) onArchivePact;
  final bool pactTimelineEnabled;
  final VoidCallback? onOpenTimeline;
  final VoidCallback? onStartBreak;
  final Future<void> Function()? onStopBreak;
  final bool pactChainingEnabled;
  final VoidCallback? onOpenPreviousPact;
  final VoidCallback? onOpenNextPact;
  final VoidCallback? onAdjustAndStartAgain;
  final ScrollController? scrollController;
  final SlideDirection? chainNavigationDirection;
  final PactDetailState? previousState;
  final String? originalPactId;

  const _PactDetailContent({
    required this.state,
    required this.l10n,
    required this.onStopPact,
    required this.onSaveNote,
    required this.onArchivePact,
    this.pactTimelineEnabled = false,
    this.onOpenTimeline,
    this.onStartBreak,
    this.onStopBreak,
    this.pactChainingEnabled = false,
    this.onOpenPreviousPact,
    this.onOpenNextPact,
    this.onAdjustAndStartAgain,
    this.scrollController,
    this.chainNavigationDirection,
    this.previousState,
    this.originalPactId,
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

    // Outgoing pact's values, only present mid-transition (HAB-206 WU3).
    final previousPact = previousState?.pact;
    final previousStats = previousState?.stats;
    final previousStatusText = previousPact != null ? pactStatusText(l10n, previousPact.status) : null;
    final previousStatusColor = previousPact != null ? PactStatusColors.material.forStatus(previousPact.status) : null;
    final previousDaysLeft = previousPact?.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    // Pinned to the widest possible status label so the badge doesn't resize
    // (and shift the Row) when crossfading between two labels (HAB-206 WU3).
    final badgeWidth = StatusBadge.widestOf(context, PactStatus.values.map((s) => pactStatusText(l10n, s)));

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      // Keyed by the screen's original entry pact id (HAB-202's disambiguation
      // from an underlying route), kept stable across an in-place chain-link
      // swap (HAB-206 WU3) so un-animated content doesn't pop in/out on swap.
      key: Key('pact-detail-scroll-view-${originalPactId ?? pact.id}'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16 + bottomInset),
      children: [
        // Habit name + status badge, each wrapped so only the value animates (HAB-206 WU3).
        Row(
          children: [
            Expanded(
              child: AnimatedValueTransition(
                direction: chainNavigationDirection,
                previousChild: previousPact != null && previousPact.habitName != pact.habitName
                    ? Text(
                        previousPact.habitName,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      )
                    : null,
                child: Text(
                  pact.habitName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            AnimatedValueTransition(
              direction: chainNavigationDirection,
              previousChild: previousStatusText != null && previousStatusText != statusText
                  ? StatusBadge(text: previousStatusText, color: previousStatusColor!, width: badgeWidth)
                  : null,
              child: StatusBadge(text: statusText, color: statusColor, width: badgeWidth),
            ),
          ],
        ),
        // 3-slot chevron-stripe carousel (HAB-206 WU4), replacing HAB-202's
        // plain Previous/Next links — grouped right under the title,
        // independent of the bottom action area (which shows only "Adjust
        // and start again", and only while no successor exists yet).
        if (pactChainingEnabled && (state.predecessorPact != null || state.successorPact != null)) ...[
          const SizedBox(height: AppSpacing.s12),
          ChainNavigationStripe(
            predecessor: state.predecessorPact,
            successor: state.successorPact,
            previousPredecessor: previousState?.predecessorPact,
            previousSuccessor: previousState?.successorPact,
            direction: chainNavigationDirection,
            onOpenPrevious: onOpenPreviousPact,
            onOpenNext: onOpenNextPact,
          ),
        ],
        const SizedBox(height: AppSpacing.s24),

        // "In a break" banner + Resume pact action (HAB-195 WU5.2) — shown
        // instead of the Take a Break button when a break already blocks
        // starting a new one. Animated via AnimatedReveal (mirrors the
        // break-creation flow's end-date-row toggle) so resuming the pact
        // fades/collapses the banner instead of it vanishing instantly.
        BreakBannerReveal(
          activeBreak: state.isBreakActiveNow ? state.activeBreak : null,
          isStopping: state.isStoppingBreak,
          stopError: state.stopBreakError,
          onStopBreak: onStopBreak,
          l10n: l10n,
        ),

        // Each stat card's count is individually animated (HAB-206 WU3).
        SectionHeader(title: l10n.sectionStats, labelColor: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _animatedStatCard(
                l10n.statsDone,
                l10n.statsShowups(stats.showupsDone),
                previousStats != null ? l10n.statsShowups(previousStats.showupsDone) : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _animatedStatCard(
                l10n.statsFailed,
                l10n.statsShowups(stats.showupsFailed),
                previousStats != null ? l10n.statsShowups(previousStats.showupsFailed) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            // Presence (Remaining/Cancelled vs. absent for completed) is an unanimated toggle; label+value crossfade.
            if (_thirdStatCell(pact.status) != null)
              Expanded(
                child: _animatedThirdStatCell(
                  currentStatus: pact.status,
                  currentValue: stats.showupsRemaining,
                  previousStatus: previousPact?.status,
                  previousValue: previousStats?.showupsRemaining,
                ),
              ),
            if (pact.status != PactStatus.completed) const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _animatedStatCard(
                l10n.statsStreak,
                l10n.statsShowups(stats.currentStreak),
                previousStats != null ? l10n.statsShowups(previousStats.currentStreak) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),

        // Each tile's value (or label, for "days remaining") is individually animated (HAB-206 WU3).
        SectionHeader(title: l10n.sectionTimeline, labelColor: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.pactStartDate,
          value: formatLocaleDate(pact.startDate),
          previousValue: previousPact != null ? formatLocaleDate(previousPact.startDate) : null,
          valueColor: valueColor,
          tileColor: tileColor,
        ),
        const SizedBox(height: AppSpacing.s8),
        // Reveals/collapses instead of popping (HAB-206 WU3); the spacer
        // lives inside so it collapses with the tile.
        AnimatedReveal(
          visible: pact.status == PactStatus.stopped && pact.stoppedAt != null,
          child: Column(
            // min: a `max` Column reaching through Align's heightFactor hands
            // descendants a bounded height, which made the note field below scroll internally.
            mainAxisSize: MainAxisSize.min,
            // stretch: Align (inside AnimatedReveal) loosens the incoming
            // width constraint; without stretch this shrink-wraps instead of filling the row.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _animatedDateTile(
                label: l10n.pactStoppedDate,
                value: formatLocaleDate(pact.stoppedAt ?? previousPact?.stoppedAt ?? pact.startDate),
                previousValue: previousPact?.stoppedAt != null ? formatLocaleDate(previousPact!.stoppedAt!) : null,
                valueColor: valueColor,
                tileColor: tileColor,
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        ),
        _animatedDateTile(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          value: formatLocaleDate(pact.endDate),
          previousLabel: previousPact != null
              ? (previousPact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate)
              : null,
          previousValue: previousPact != null ? formatLocaleDate(previousPact.endDate) : null,
          valueColor: valueColor,
          tileColor: tileColor,
        ),
        AnimatedReveal(
          visible: pact.status == PactStatus.active && daysLeft >= 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s8),
              _animatedDateTile(
                label: l10n.daysRemaining(pact.status == PactStatus.active ? daysLeft : previousDaysLeft ?? daysLeft),
                tileColor: tileColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.summaryShowupDuration,
          value: l10n.showupDurationMinutes(pact.showupDuration.inMinutes),
          previousValue:
              previousPact != null ? l10n.showupDurationMinutes(previousPact.showupDuration.inMinutes) : null,
          valueColor: valueColor,
          tileColor: tileColor,
        ),
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.summaryReminder,
          value: reminderDescription(l10n, pact.reminderOffset),
          previousValue: previousPact != null ? reminderDescription(l10n, previousPact.reminderOffset) : null,
          valueColor: valueColor,
          tileColor: tileColor,
        ),

        // View Timeline entry point (flag-gated)
        if (pactTimelineEnabled && onOpenTimeline != null) ...[
          const SizedBox(height: AppSpacing.s8),
          TextButton(
            key: const Key('pact-detail-timeline-button'),
            onPressed: onOpenTimeline,
            child: Text(l10n.pactDetailViewTimeline),
          ),
        ],

        // Editable note section for inactive pacts, reveals/collapses (HAB-206 WU3).
        // Falls back to the outgoing pact's stopReason while collapsing.
        AnimatedReveal(
          visible: pact.status != PactStatus.active,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s24),
              PactNoteSection(
                savedNote: pact.stopReason ?? previousPact?.stopReason,
                isSaving: state.isSavingNote,
                noteError: state.noteError,
                labelColor: theme.colorScheme.onSurfaceVariant,
                errorColor: theme.colorScheme.error,
                onSaveNote: onSaveNote,
                slots: (
                  buildNoteField: (context, controller) => TextField(
                        key: const Key('pact-note-field'),
                        controller: controller,
                        decoration: InputDecoration(hintText: l10n.stopPactReasonHint),
                        maxLines: null,
                        minLines: 3,
                      ),
                  buildSaveButton: (context, onPressed) => FilledButton(
                        key: const Key('pact-note-save-button'),
                        onPressed: onPressed,
                        child: Text(l10n.pactNoteSave),
                      ),
                ),
              ),
            ],
          ),
        ),

        // Archive section, same reveal/collapse treatment. No stretch — the
        // button stays a small centered link, so the header needs its own explicit left alignment.
        AnimatedReveal(
          visible: pact.status != PactStatus.active,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.s24),
              Align(
                alignment: Alignment.centerLeft,
                child: SectionHeader(title: l10n.sectionArchive, labelColor: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.s8),
              OutlinedButton(
                key: const Key('archive-pact-button'),
                onPressed: state.isArchiving ? null : () => onArchivePact(!pact.archived),
                child: state.isArchiving
                    ? const SizedBox(
                        height: AppSpacing.s20, width: AppSpacing.s20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(pact.archived ? l10n.unarchivePact : l10n.archivePact),
              ),
            ],
          ),
        ),

        // Take a break + stop pact, set off by a divider (HAB-195: keep
        // "Take a break" closer to "Stop pact" than "View Timeline"). Reveals/collapses (HAB-206 WU3).
        AnimatedReveal(
          visible: pact.status == PactStatus.active,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.s24),
              const Divider(),
              const SizedBox(height: AppSpacing.s8),
              if (onStartBreak != null) ...[
                TextButton(
                  key: const Key('pact-detail-start-break-button'),
                  onPressed: onStartBreak,
                  child: Text(l10n.startBreak),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              if (state.stopError != null) ...[
                Text(l10n.stopPactError, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: AppSpacing.s8),
              ],
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: state.isStopping ? null : () => _showStopDialog(context),
                child: state.isStopping
                    ? SizedBox(
                        height: AppSpacing.s20,
                        width: AppSpacing.s20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onError))
                    : Text(l10n.stopPact),
              ),
            ],
          ),
        ),

        // Adjust and start again — bottom action area for a finished pact
        // with no successor yet (HAB-202). Once a successor exists, this is
        // simply absent — "Next Pact" lives with "Previous Pact" under the
        // title instead (see above), not here. No divider here (unlike the
        // active-pact actions above) — an earlier attempt added one and
        // pushed this button past the reachable scroll extent on a short
        // viewport, breaking WU3's own nav-stack scenarios (see
        // docs/knowledge/notes/HAB-202.md).
        if (pactChainingEnabled &&
            pact.status != PactStatus.active &&
            state.successorPact == null &&
            onAdjustAndStartAgain != null) ...[
          const SizedBox(height: AppSpacing.s24),
          FilledButton(
            key: const Key('pact-detail-adjust-and-start-again-button'),
            onPressed: onAdjustAndStartAgain,
            child: Text(l10n.pactDetailAdjustAndStartAgain),
          ),
        ],
      ],
    );
  }

  Widget _animatedStatCard(String label, String value, String? previousValue) {
    return AnimatedValueTransition(
      direction: chainNavigationDirection,
      previousChild:
          previousValue != null && previousValue != value ? _StatCard(label: label, value: previousValue) : null,
      child: _StatCard(label: label, value: value),
    );
  }

  // Remaining/Cancelled — l10n.statsRemaining for an active pact,
  // l10n.statsCancelled for a stopped one, absent entirely for a completed
  // one (there's nothing left to call either "remaining" or "cancelled").
  String? _thirdStatCell(PactStatus status) => switch (status) {
        PactStatus.active => l10n.statsRemaining,
        PactStatus.stopped => l10n.statsCancelled,
        PactStatus.completed => null,
      };

  // Crossfades label+value together, unlike _animatedStatCard — the label
  // itself changes on the most common hop (active <-> stopped), so gating on an unchanged label would rarely animate.
  Widget _animatedThirdStatCell({
    required PactStatus currentStatus,
    required int currentValue,
    required PactStatus? previousStatus,
    required int? previousValue,
  }) {
    final currentLabel = _thirdStatCell(currentStatus)!;
    final previousLabel = previousStatus != null ? _thirdStatCell(previousStatus) : null;

    Widget? previousChild;
    if (previousLabel != null && previousValue != null) {
      final changed = previousLabel != currentLabel || previousValue != currentValue;
      if (changed) previousChild = _StatCard(label: previousLabel, value: l10n.statsShowups(previousValue));
    }

    return AnimatedValueTransition(
      direction: chainNavigationDirection,
      previousChild: previousChild,
      child: _StatCard(label: currentLabel, value: l10n.statsShowups(currentValue)),
    );
  }

  Widget _animatedDateTile({
    required String label,
    String? previousLabel,
    String? value,
    String? previousValue,
    Color? valueColor,
    required Color tileColor,
  }) {
    final effectivePreviousLabel = previousLabel ?? label;
    return AnimatedValueTransition(
      direction: chainNavigationDirection,
      previousChild: previousValue != null && (effectivePreviousLabel != label || previousValue != value)
          ? DateRowTile(
              label: effectivePreviousLabel,
              value: previousValue,
              valueColor: valueColor ?? Colors.black87,
              backgroundColor: tileColor,
              cornerRadius: 12,
            )
          : null,
      child: DateRowTile(
        label: label,
        value: value,
        valueColor: valueColor ?? Colors.black87,
        backgroundColor: tileColor,
        cornerRadius: 12,
      ),
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
              const SizedBox(height: AppSpacing.s12),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
        // stretch: under AnimatedValueTransition's Stack, a start-aligned
        // Column would shrink-wrap to the text width, jumping the card's width mid-transition (HAB-206 WU3).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.s4),
            Text(value, style: AppTypography.valueEmphasis),
          ],
        ),
      ),
    );
  }
}
