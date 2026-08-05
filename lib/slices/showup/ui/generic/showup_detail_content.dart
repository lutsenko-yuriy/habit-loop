import 'package:flutter/material.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';
import 'package:habit_loop/theme/widgets/status_badge.dart';

/// Platform-specific UI slots for [ShowupDetailContent].
typedef ShowupDetailSlots = ({
  Widget Function(BuildContext context, ShowupDetailState state) buildActionButtons,
  Widget Function(BuildContext context, TextEditingController controller) buildNoteField,
  Widget Function(BuildContext context, VoidCallback? onPressed) buildSaveButton,
  Widget Function(BuildContext context) buildErrorContainer,
  // onPressed is null when the note is empty (button visible but disabled).
  Widget Function(BuildContext context, VoidCallback? onRedeem) buildRedemptionButton,
  Widget Function(BuildContext context) buildRedemptionHint,
  Widget Function(BuildContext context, VoidCallback onPressed) buildStartBreakButton,
});

/// Shared showup detail body — owns [TextEditingController] lifecycle and
/// renders the common layout. Platform chrome lives in the enclosing Scaffold.
class ShowupDetailContent extends StatefulWidget {
  final ShowupDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function() onRedeemShowup;
  final VoidCallback? onOpenPact;
  // Null hides the "Take a break" tail-zone entry point (HAB-195 WU4.2).
  final VoidCallback? onStartBreak;
  final ShowupStatusColors statusColors;
  final Color labelColor;
  final Color tileColor;
  final Color linkColor;
  final ShowupDetailSlots slots;

  /// Extra padding added to the bottom of the scroll view — pass
  /// [MediaQuery.paddingOf(context).bottom] on iOS when [SafeArea.bottom] is
  /// false so the last item clears the home indicator.
  final double bottomPadding;

  const ShowupDetailContent({
    super.key,
    required this.state,
    required this.l10n,
    required this.onSaveNote,
    required this.onRedeemShowup,
    required this.statusColors,
    required this.labelColor,
    required this.tileColor,
    required this.linkColor,
    required this.slots,
    this.onOpenPact,
    this.onStartBreak,
    this.bottomPadding = 0,
  });

  @override
  State<ShowupDetailContent> createState() => _ShowupDetailContentState();
}

class _ShowupDetailContentState extends State<ShowupDetailContent> {
  late TextEditingController _noteController;

  // Outgoing badge, held for the crossfade window after uiState changes (WU3).
  ShowupUiState? _previousUiState;

  // Last non-null callback, so a collapsing AnimatedReveal block keeps a
  // valid onTap/onPressed instead of a now-null widget field (WU3).
  VoidCallback? _lastOnOpenPact;
  VoidCallback? _lastOnStartBreak;

  // Buttons' state frozen (isSaving: false) once the block starts
  // collapsing, so it fades from its enabled look, not a disabled one (WU3).
  ShowupDetailState? _lastActionButtonsState;

  bool _showsActionButtons(ShowupDetailState s) =>
      s.showup?.status == ShowupStatus.pending && s.uiState != ShowupUiState.onBreak;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.state.showup?.note ?? '');
    _lastOnOpenPact = widget.onOpenPact;
    _lastOnStartBreak = widget.onStartBreak;
    if (_showsActionButtons(widget.state)) _lastActionButtonsState = widget.state.copyWith(isSaving: false);
  }

  @override
  void didUpdateWidget(ShowupDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNote = widget.state.showup?.note ?? '';
    if (oldWidget.state.showup?.note != widget.state.showup?.note && _noteController.text != newNote) {
      _noteController.text = newNote;
    }
    if (widget.onOpenPact != null) _lastOnOpenPact = widget.onOpenPact;
    if (widget.onStartBreak != null) _lastOnStartBreak = widget.onStartBreak;
    if (_showsActionButtons(widget.state)) _lastActionButtonsState = widget.state.copyWith(isSaving: false);

    final newUiState = widget.state.uiState;
    if (oldWidget.state.uiState != newUiState) {
      _previousUiState = oldWidget.state.uiState;
      Future.delayed(kAnimatedValueTransitionDuration, () {
        // Only clear if uiState hasn't moved on again since this timer was
        // scheduled — a later change already owns the reset by then.
        if (mounted && widget.state.uiState == newUiState) {
          setState(() => _previousUiState = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final showup = state.showup;
    assert(showup != null, 'ShowupDetailContent must only be shown after a successful load');
    if (showup == null) return const SizedBox.shrink();

    final l10n = widget.l10n;
    final scheduledDate = formatShowupDate(showup.scheduledAt);
    final scheduledTime = formatShowupTime(context, showup.scheduledAt);
    final durationMins = showup.duration.inMinutes;
    final isPending = showup.status == ShowupStatus.pending;
    final uiState = state.uiState;
    final statusColor = widget.statusColors.forUiState(uiState);
    final statusText = showupUiStateText(l10n, uiState);
    // Pinned to the widest possible status label so the badge doesn't resize
    // (and shift the Row) when crossfading between two labels (HAB-213 WU3).
    final badgeWidth = StatusBadge.widestOf(context, ShowupUiState.values.map((s) => showupUiStateText(l10n, s)));
    final previousUiState = _previousUiState;

    return ListView(
      padding:
          EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16 + widget.bottomPadding),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.habitName ?? l10n.showupHabitDeleted,
                style: AppTypography.sectionTitle,
              ),
            ),
            AnimatedValueTransition(
              direction: null,
              previousChild: previousUiState != null && previousUiState != uiState
                  ? StatusBadge(
                      text: showupUiStateText(l10n, previousUiState),
                      color: widget.statusColors.forUiState(previousUiState),
                      width: badgeWidth,
                    )
                  : null,
              child: StatusBadge(text: statusText, color: statusColor, width: badgeWidth),
            ),
          ],
        ),
        // Reveals/collapses instead of popping (HAB-213 WU3); not stretched —
        // this is a link, not a full-width control.
        AnimatedReveal(
          visible: widget.onOpenPact != null,
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s4),
              GestureDetector(
                key: const Key('showup-pact-link'),
                onTap: _lastOnOpenPact,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.showupViewPactDetails,
                      style: AppTypography.caption.copyWith(color: widget.linkColor),
                    ),
                    Icon(Icons.chevron_right, size: 13, color: widget.linkColor),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        DateRowTile(
          label: l10n.showupDetailScheduledAt,
          value: '$scheduledDate  $scheduledTime',
          valueColor: widget.labelColor,
          backgroundColor: widget.tileColor,
        ),
        const SizedBox(height: AppSpacing.s8),
        DateRowTile(
          label: l10n.showupDetailDuration,
          value: l10n.showupDurationMinutes(durationMins),
          valueColor: widget.labelColor,
          backgroundColor: widget.tileColor,
        ),
        const SizedBox(height: AppSpacing.s24),
        // The six blocks below reveal/collapse via AnimatedReveal rather than
        // popping in/out, matching the pact detail screen's treatment for the
        // same class of conditional block (HAB-213 WU3).
        AnimatedReveal(
          visible: state.wasAutoFailed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.slots.buildErrorContainer(context),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
        AnimatedReveal(
          visible: widget.onStartBreak != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.slots.buildStartBreakButton(context, _lastOnStartBreak ?? () {}),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
        // On break, the "On break" badge above already carries the state —
        // Mark Done/Failed would be misleading actions, so hide them entirely
        // rather than show a disabled or replaced control (HAB-213).
        AnimatedReveal(
          visible: isPending && uiState != ShowupUiState.onBreak,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live state while shown; frozen snapshot once collapsing.
              widget.slots.buildActionButtons(
                context,
                (isPending && uiState != ShowupUiState.onBreak) ? state : (_lastActionButtonsState ?? state),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
        AnimatedReveal(
          visible: state.markError != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.showupMarkError,
                style: TextStyle(color: widget.statusColors.failed),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        ),
        SectionHeader(title: l10n.showupNoteLabel, labelColor: widget.labelColor),
        const SizedBox(height: AppSpacing.s8),
        widget.slots.buildNoteField(context, _noteController),
        const SizedBox(height: AppSpacing.s8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _noteController,
          builder: (context, value, _) {
            final savedNote = widget.state.showup?.note ?? '';
            final hasChanged = value.text != savedNote;
            final onPressed =
                (widget.state.isSaving || !hasChanged) ? null : () => widget.onSaveNote(_noteController.text);
            return Align(
              alignment: Alignment.centerRight,
              child: widget.slots.buildSaveButton(context, onPressed),
            );
          },
        ),
        AnimatedReveal(
          visible: state.noteError != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s4),
              Text(
                l10n.showupNoteError,
                style: TextStyle(color: widget.statusColors.failed),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Redemption section — below the note so the hint text is no longer
        // directionally misleading. AnimatedSwitcher fades between the enabled,
        // disabled, and gone states.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: state.canRedeem
              ? Padding(
                  key: const ValueKey('redeem-section'),
                  padding: const EdgeInsets.only(top: AppSpacing.s16),
                  child: () {
                    final hasNote = showup.note?.isNotEmpty ?? false;
                    final enabled = hasNote && !state.isSaving;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Keyed on enabled so AnimatedSwitcher cross-fades when
                        // the button transitions between disabled and active states.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: SizedBox(
                            key: ValueKey(enabled),
                            width: double.infinity,
                            child: widget.slots.buildRedemptionButton(
                              context,
                              enabled ? () => widget.onRedeemShowup() : null,
                            ),
                          ),
                        ),
                        if (!hasNote) ...[
                          const SizedBox(height: AppSpacing.s8),
                          widget.slots.buildRedemptionHint(context),
                        ],
                      ],
                    );
                  }(),
                )
              : const SizedBox.shrink(key: ValueKey('redeem-gone')),
        ),
      ],
    );
  }
}
