import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider, Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/break_banner.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_animated_value.dart';
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

  /// Direction of the most recent chain-link navigation (HAB-206 WU3) — drives
  /// which way an animated value slides when it changes. `null` on the
  /// initial load, before any chain-link has been tapped.
  final ChainNavigationDirection? chainNavigationDirection;

  /// The outgoing pact's state (HAB-206 WU3), held for the duration of a
  /// chain-link navigation's visual transition. Non-null only while a
  /// transition is in flight; each value (title, stat, date...) compares
  /// itself against this to decide whether it has anything to animate.
  final PactDetailState? previousState;

  /// The pact id [PactDetailScreen] was originally opened with (HAB-206 WU3)
  /// — stable for this screen instance's whole lifetime, unlike [state]'s
  /// own pact id, which changes on every in-place chain-link swap. Used to
  /// key the content `ListView` so its subtree (and everything inside it —
  /// `BreakBannerReveal`'s own reveal animation, the notes section, etc.)
  /// survives a chain-link swap instead of being torn down and rebuilt from
  /// scratch, which otherwise makes those un-animated widgets pop in/out
  /// abruptly rather than updating smoothly in place. Falls back to the
  /// currently-shown pact's id when omitted (e.g. by tests that don't
  /// exercise chain-link navigation), matching the pre-WU3 keying.
  final String? originalPactId;

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
    this.chainNavigationDirection,
    this.previousState,
    this.originalPactId,
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
                // While a chain-link swap's reload is in flight, keep showing
                // the outgoing pact's own (already-loaded) content instead of
                // a spinner (HAB-206 WU3) — previousState is only ever set
                // for exactly that case (see PactDetailScreen's own doc
                // comment), so this can't mask a genuine first-open loading
                // state. Robust to however long the reload actually takes,
                // unlike trying to always out-cache the race: the content
                // only ever *looks* frozen for a moment, never blank.
                child: (state.isLoading && previousState?.pact == null)
                    ? const Center(child: CupertinoActivityIndicator())
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
              // Invisible marker (HAB-206 WU3) — the content ListView is
              // keyed by [originalPactId] (stable across chain-link swaps,
              // see its own doc comment), so it no longer reflects which
              // pact is *currently* shown. Integration scenarios read that
              // off this marker's key instead (see pact_chain_test.dart's
              // _currentDetailPactId).
              if (state.pact != null) SizedBox.shrink(key: ValueKey('pact-detail-current-pact-id-${state.pact!.id}')),
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
  final ChainNavigationDirection? chainNavigationDirection;
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
    final today = DateTime.now();
    final daysLeft = pact.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    final statusText = pactStatusText(l10n, pact.status);
    final statusColor = PactStatusColors.cupertino(context).forStatus(pact.status);
    final fill = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    // Outgoing pact's own values (HAB-206 WU3), only present mid-transition —
    // each animated field below compares against these to decide whether it
    // has anything to visibly swap.
    final previousPact = previousState?.pact;
    final previousStats = previousState?.stats;
    final previousStatusText = previousPact != null ? pactStatusText(l10n, previousPact.status) : null;
    final previousStatusColor =
        previousPact != null ? PactStatusColors.cupertino(context).forStatus(previousPact.status) : null;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      // Keyed by the screen's original entry pact id, not the currently-
      // shown one (HAB-206 WU3) — this disambiguates this screen's own
      // Scrollable from an earlier PactDetailScreen still mounted underneath
      // it (HAB-202; Navigator keeps prior routes mounted by default), same
      // as before, but staying STABLE across an in-place chain-link swap is
      // now also load-bearing: a changing key would tear down and rebuild
      // this whole subtree on every swap, which is what previously made
      // BreakBannerReveal's own reveal animation (and anything else in here
      // that isn't explicitly wrapped in PactDetailAnimatedValue) pop in/out
      // abruptly instead of updating in place.
      key: Key('pact-detail-scroll-view-${originalPactId ?? pact.id}'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16 + bottomInset),
      children: [
        // Habit name + status badge. Only the value each shows is wrapped in
        // PactDetailAnimatedValue (HAB-206 WU3) — a habit name or status
        // change animates in place; the Row itself does not.
        Row(
          children: [
            Expanded(
              child: PactDetailAnimatedValue(
                direction: chainNavigationDirection,
                previousChild: previousPact != null && previousPact.habitName != pact.habitName
                    ? Text(previousPact.habitName, style: AppTypography.sectionTitle)
                    : null,
                child: Text(
                  pact.habitName,
                  style: AppTypography.sectionTitle,
                ),
              ),
            ),
            PactDetailAnimatedValue(
              direction: chainNavigationDirection,
              previousChild: previousStatusText != null && previousStatusText != statusText
                  ? StatusBadge(text: previousStatusText, color: previousStatusColor!)
                  : null,
              child: StatusBadge(text: statusText, color: statusColor),
            ),
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

        // Stats cards — each card's count is individually wrapped in
        // PactDetailAnimatedValue (HAB-206 WU3) so only the number itself
        // animates when it changes; the card, its label, and section header
        // stay static.
        SectionHeader(title: l10n.sectionStats, labelColor: HabitLoopColors.secondaryText(context)),
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
            // The third cell's label (Remaining vs. Cancelled) — and whether
            // it's shown at all — depends on status, which can differ
            // structurally between the outgoing and incoming pact. Only
            // animate the value when the outgoing pact had the exact same
            // label (i.e. the same status), so a mismatched label+value pair
            // never gets built as the outgoing snapshot.
            if (pact.status == PactStatus.active)
              Expanded(
                child: _animatedStatCard(
                  l10n.statsRemaining,
                  l10n.statsShowups(stats.showupsRemaining),
                  previousStats != null && previousPact?.status == PactStatus.active
                      ? l10n.statsShowups(previousStats.showupsRemaining)
                      : null,
                ),
              )
            else if (pact.status == PactStatus.stopped)
              Expanded(
                child: _animatedStatCard(
                  l10n.statsCancelled,
                  l10n.statsShowups(stats.showupsRemaining),
                  previousStats != null && previousPact?.status == PactStatus.stopped
                      ? l10n.statsShowups(previousStats.showupsRemaining)
                      : null,
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

        // Time details — each tile's value (or, for the label-only "days
        // remaining" tile, its label) is individually wrapped in
        // PactDetailAnimatedValue (HAB-206 WU3) so only the date/duration
        // text itself animates when it changes.
        SectionHeader(title: l10n.sectionTimeline, labelColor: HabitLoopColors.secondaryText(context)),
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.pactStartDate,
          value: formatLocaleDate(pact.startDate),
          previousValue: previousPact != null ? formatLocaleDate(previousPact.startDate) : null,
          valueColor: HabitLoopColors.secondaryText(context),
          tileColor: fill,
        ),
        const SizedBox(height: AppSpacing.s8),
        // Presence (stopped-date tile) and label ("Ends" vs. "Ended", days-
        // remaining tile) can differ structurally between the outgoing and
        // incoming pact, so these are left unanimated (no previousValue).
        if (pact.status == PactStatus.stopped && pact.stoppedAt != null) ...[
          _animatedDateTile(
            label: l10n.pactStoppedDate,
            value: formatLocaleDate(pact.stoppedAt!),
            valueColor: HabitLoopColors.secondaryText(context),
            tileColor: fill,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        _animatedDateTile(
          label: pact.status == PactStatus.active ? l10n.pactEndDate : l10n.pactEndedDate,
          value: formatLocaleDate(pact.endDate),
          previousValue: previousPact != null ? formatLocaleDate(previousPact.endDate) : null,
          valueColor: HabitLoopColors.secondaryText(context),
          tileColor: fill,
        ),
        if (pact.status == PactStatus.active && daysLeft >= 0) ...[
          const SizedBox(height: AppSpacing.s8),
          _animatedDateTile(label: l10n.daysRemaining(daysLeft), tileColor: fill),
        ],
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.summaryShowupDuration,
          value: l10n.showupDurationMinutes(pact.showupDuration.inMinutes),
          previousValue:
              previousPact != null ? l10n.showupDurationMinutes(previousPact.showupDuration.inMinutes) : null,
          valueColor: HabitLoopColors.secondaryText(context),
          tileColor: fill,
        ),
        const SizedBox(height: AppSpacing.s8),
        _animatedDateTile(
          label: l10n.summaryReminder,
          value: reminderDescription(l10n, pact.reminderOffset),
          previousValue: previousPact != null ? reminderDescription(l10n, previousPact.reminderOffset) : null,
          valueColor: HabitLoopColors.secondaryText(context),
          tileColor: fill,
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

  Widget _animatedStatCard(String label, String value, String? previousValue) {
    return PactDetailAnimatedValue(
      direction: chainNavigationDirection,
      previousChild:
          previousValue != null && previousValue != value ? _StatCard(label: label, value: previousValue) : null,
      child: _StatCard(label: label, value: value),
    );
  }

  Widget _animatedDateTile({
    required String label,
    String? value,
    String? previousValue,
    Color? valueColor,
    required Color tileColor,
  }) {
    return PactDetailAnimatedValue(
      direction: chainNavigationDirection,
      previousChild: previousValue != null && previousValue != value
          ? DateRowTile(
              label: label,
              value: previousValue,
              valueColor: valueColor ?? Colors.black87,
              backgroundColor: tileColor,
            )
          : null,
      child: DateRowTile(
        label: label,
        value: value,
        valueColor: valueColor ?? Colors.black87,
        backgroundColor: tileColor,
      ),
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
      // stretch, not start (HAB-206 WU3) — under PactDetailAnimatedValue's
      // Stack mid-transition, this Column's width constraint is loosened;
      // start-aligned, it would shrink-wrap to the text's intrinsic width
      // instead of keeping the card's usual full-cell width, causing a
      // visible width jump for the transition's duration.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: HabitLoopColors.secondaryText(context))),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: AppTypography.valueEmphasis),
        ],
      ),
    );
  }
}
