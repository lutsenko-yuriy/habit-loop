import 'package:flutter/material.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
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
});

/// Shared showup detail body — owns [TextEditingController] lifecycle and
/// renders the common layout. Platform chrome lives in the enclosing Scaffold.
class ShowupDetailContent extends StatefulWidget {
  final ShowupDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function() onRedeemShowup;
  final VoidCallback? onOpenPact;
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
    this.bottomPadding = 0,
  });

  @override
  State<ShowupDetailContent> createState() => _ShowupDetailContentState();
}

class _ShowupDetailContentState extends State<ShowupDetailContent> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.state.showup?.note ?? '');
  }

  @override
  void didUpdateWidget(ShowupDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNote = widget.state.showup?.note ?? '';
    if (oldWidget.state.showup?.note != widget.state.showup?.note && _noteController.text != newNote) {
      _noteController.text = newNote;
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
    if (showup == null) {
      // ignore: avoid_print
      print(
        'DIAG ShowupDetailContent.build: showup=null isLoading=${state.isLoading} '
        'at ${DateTime.now().toIso8601String()}',
      );
      return const SizedBox.shrink();
    }
    // ignore: avoid_print
    print(
        'DIAG ShowupDetailContent.build: showup=${showup.id} note=${showup.note} at ${DateTime.now().toIso8601String()}');

    final l10n = widget.l10n;
    final scheduledDate = formatShowupDate(showup.scheduledAt);
    final scheduledTime = formatShowupTime(context, showup.scheduledAt);
    final durationMins = showup.duration.inMinutes;
    final isPending = showup.status == ShowupStatus.pending;
    final uiState = state.uiState;
    final statusColor = widget.statusColors.forUiState(uiState);
    final statusText = showupUiStateText(l10n, uiState);

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
            StatusBadge(text: statusText, color: statusColor),
          ],
        ),
        if (widget.onOpenPact != null) ...[
          const SizedBox(height: AppSpacing.s4),
          GestureDetector(
            key: const Key('showup-pact-link'),
            onTap: widget.onOpenPact,
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
        if (state.wasAutoFailed) ...[
          widget.slots.buildErrorContainer(context),
          const SizedBox(height: AppSpacing.s16),
        ],
        if (isPending) ...[
          widget.slots.buildActionButtons(context, state),
          const SizedBox(height: AppSpacing.s16),
        ],
        if (state.markError != null) ...[
          Text(
            l10n.showupMarkError,
            style: TextStyle(color: widget.statusColors.failed),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
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
        if (state.noteError != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            l10n.showupNoteError,
            style: TextStyle(color: widget.statusColors.failed),
            textAlign: TextAlign.center,
          ),
        ],
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
