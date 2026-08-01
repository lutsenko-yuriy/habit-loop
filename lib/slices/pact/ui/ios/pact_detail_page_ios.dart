import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/break_banner.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_content_transition.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_note_section.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_status_colors.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';
import 'package:habit_loop/theme/widgets/status_badge.dart';

class PactDetailPageIos extends StatelessWidget {
  final PactDetailState state;
  final Future<void> Function(String? reason) onStopPact;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function(bool archive) onArchivePact;

  /// Called when the user taps the pencil edit button in the nav bar.
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
  final String? contentId;
  final PactDetailTransitionDirection? transitionDirection;

  const PactDetailPageIos({
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
    this.contentId,
    this.transitionDirection,
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
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : state.loadError != null
                        ? Center(child: Text(state.loadError.toString()))
                        : PactDetailContentTransition(
                            contentId: contentId ?? state.pact!.id,
                            direction: transitionDirection,
                            child: _PactDetailContent(
                              state: state,
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
                            ),
                          ),
              ),
            ],
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

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      // Pact-specific key (HAB-202) — disambiguates this screen's own
      // Scrollable from an earlier PactDetailScreen still mounted underneath
      // it (Navigator keeps prior routes mounted by default) when a test
      // needs to scroll a specific screen's content into view.
      key: Key('pact-detail-scroll-view-${pact.id}'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16 + bottomInset),
      children: [
        // Habit name + status badge
        Row(
          children: [
            Expanded(
              child: Text(
                pact.habitName,
                style: AppTypography.sectionTitle,
              ),
            ),
            StatusBadge(text: statusText, color: statusColor),
          ],
        ),
        // Previous/Next Pact links (HAB-202) — grouped in a row right under
        // the title, independent of the bottom action area (which shows
        // only "Adjust and start again", and only while no successor exists
        // yet). spaceBetween pins Next to the trailing edge, mirroring a
        // pagination-style Previous/Next affordance, and degenerates to a
        // plain leading-aligned single link when only one is present.
        // minimumSize: Size.zero — CupertinoButton's 44pt default tap-target
        // height otherwise dwarfs these single-line secondary links.
        // Flexible — long habit names must not overflow the Row on a narrow
        // screen.
        if (pactChainingEnabled && (state.predecessorPact != null || state.successorPact != null)) ...[
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (state.predecessorPact != null)
                Flexible(
                  child: CupertinoButton(
                    key: const Key('pact-detail-previous-pact-link'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onOpenPreviousPact,
                    child: Text(
                      l10n.pactDetailPreviousPact(state.predecessorPact!.habitName),
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (state.successorPact != null)
                Flexible(
                  child: CupertinoButton(
                    key: const Key('pact-detail-next-pact-link'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onOpenNextPact,
                    child: Text(
                      l10n.pactDetailNextPact(state.successorPact!.habitName),
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
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

        // Stats cards
        SectionHeader(title: l10n.sectionStats, labelColor: HabitLoopColors.secondaryText(context)),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(child: _StatCard(label: l10n.statsDone, value: l10n.statsShowups(stats.showupsDone))),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: _StatCard(label: l10n.statsFailed, value: l10n.statsShowups(stats.showupsFailed))),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            if (pact.status == PactStatus.active)
              Expanded(child: _StatCard(label: l10n.statsRemaining, value: l10n.statsShowups(stats.showupsRemaining)))
            else if (pact.status == PactStatus.stopped)
              Expanded(child: _StatCard(label: l10n.statsCancelled, value: l10n.statsShowups(stats.showupsRemaining))),
            if (pact.status != PactStatus.completed) const SizedBox(width: AppSpacing.s8),
            Expanded(child: _StatCard(label: l10n.statsStreak, value: l10n.statsShowups(stats.currentStreak))),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),

        // Time details
        SectionHeader(title: l10n.sectionTimeline, labelColor: HabitLoopColors.secondaryText(context)),
        const SizedBox(height: AppSpacing.s8),
        DateRowTile(
          label: l10n.pactStartDate,
          value: formatLocaleDate(pact.startDate),
          valueColor: HabitLoopColors.secondaryText(context),
          backgroundColor: fill,
        ),
        const SizedBox(height: AppSpacing.s8),
        if (pact.status == PactStatus.stopped && pact.stoppedAt != null) ...[
          DateRowTile(
            label: l10n.pactStoppedDate,
            value: formatLocaleDate(pact.stoppedAt!),
            valueColor: HabitLoopColors.secondaryText(context),
            backgroundColor: fill,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        DateRowTile(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          value: formatLocaleDate(pact.endDate),
          valueColor: HabitLoopColors.secondaryText(context),
          backgroundColor: fill,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: AppSpacing.s8),
          DateRowTile(label: l10n.daysRemaining(daysLeft), backgroundColor: fill),
        ],
        const SizedBox(height: AppSpacing.s8),
        DateRowTile(
          label: l10n.summaryShowupDuration,
          value: l10n.showupDurationMinutes(pact.showupDuration.inMinutes),
          valueColor: HabitLoopColors.secondaryText(context),
          backgroundColor: fill,
        ),
        const SizedBox(height: AppSpacing.s8),
        DateRowTile(
          label: l10n.summaryReminder,
          value: reminderDescription(l10n, pact.reminderOffset),
          valueColor: HabitLoopColors.secondaryText(context),
          backgroundColor: fill,
        ),

        // View Timeline entry point (flag-gated)
        if (pactTimelineEnabled && onOpenTimeline != null) ...[
          const SizedBox(height: AppSpacing.s8),
          CupertinoButton(
            key: const Key('pact-detail-timeline-button'),
            padding: EdgeInsets.zero,
            onPressed: onOpenTimeline,
            child: Text(l10n.pactDetailViewTimeline),
          ),
        ],

        // Editable note section for inactive pacts
        if (pact.status != PactStatus.active) ...[
          const SizedBox(height: AppSpacing.s24),
          PactNoteSection(
            savedNote: pact.stopReason,
            isSaving: state.isSavingNote,
            noteError: state.noteError,
            labelColor: HabitLoopColors.secondaryText(context),
            errorColor: CupertinoColors.destructiveRed.resolveFrom(context),
            onSaveNote: onSaveNote,
            slots: (
              buildNoteField: (context, controller) => CupertinoTextField(
                    key: const Key('pact-note-field'),
                    controller: controller,
                    placeholder: l10n.stopPactReasonHint,
                    maxLines: null,
                    minLines: 3,
                  ),
              buildSaveButton: (context, onPressed) => CupertinoButton(
                    key: const Key('pact-note-save-button'),
                    padding: EdgeInsets.zero,
                    onPressed: onPressed,
                    child: Text(
                      l10n.pactNoteSave,
                      style: TextStyle(
                        color: onPressed != null ? CupertinoTheme.of(context).primaryColor : CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
            ),
          ),
        ],

        // Archive section for completed and stopped pacts
        if (pact.status != PactStatus.active) ...[
          const SizedBox(height: AppSpacing.s24),
          SectionHeader(title: l10n.sectionArchive, labelColor: HabitLoopColors.secondaryText(context)),
          const SizedBox(height: AppSpacing.s8),
          CupertinoButton(
            key: const Key('archive-pact-button'),
            onPressed: state.isArchiving ? null : () => onArchivePact(!pact.archived),
            child: state.isArchiving
                ? const CupertinoActivityIndicator()
                : Text(pact.archived ? l10n.unarchivePact : l10n.archivePact),
          ),
        ],

        // Take a break + stop pact — grouped together as pact-lifecycle
        // actions, set off from the read-only sections above by a divider
        // (HAB-195: keep "Take a break" closer to "Stop pact" than to "View
        // Timeline").
        if (pact.status == PactStatus.active) ...[
          const SizedBox(height: AppSpacing.s24),
          Divider(color: CupertinoColors.separator.resolveFrom(context)),
          const SizedBox(height: AppSpacing.s8),
          if (onStartBreak != null) ...[
            CupertinoButton(
              key: const Key('pact-detail-start-break-button'),
              padding: EdgeInsets.zero,
              onPressed: onStartBreak,
              child: Text(l10n.startBreak),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          if (state.stopError != null) ...[
            Text(
              l10n.stopPactError,
              style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          CupertinoButton(
            onPressed: state.isStopping ? null : () => _showStopDialog(context),
            child: state.isStopping
                ? const CupertinoActivityIndicator()
                : Text(
                    l10n.stopPact,
                    style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context)),
                  ),
          ),
        ],

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
          CupertinoButton.filled(
            key: const Key('pact-detail-adjust-and-start-again-button'),
            onPressed: onAdjustAndStartAgain,
            child: Text(l10n.pactDetailAdjustAndStartAgain),
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
              const SizedBox(height: AppSpacing.s8),
              Text(l10n.stopPactBody),
              const SizedBox(height: AppSpacing.s12),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: HabitLoopColors.secondaryText(context))),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: AppTypography.valueEmphasis),
        ],
      ),
    );
  }
}
