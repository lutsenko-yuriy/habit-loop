import 'package:flutter/material.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/date_row_tile.dart';
import 'package:habit_loop/slices/pact/ui/generic/section_header.dart';
import 'package:habit_loop/slices/pact/ui/generic/status_badge.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

/// Platform-specific UI slots for [ShowupDetailContent].
typedef ShowupDetailSlots = ({
  Widget Function(BuildContext context, ShowupDetailState state) buildActionButtons,
  Widget Function(BuildContext context, TextEditingController controller) buildNoteField,
  Widget Function(BuildContext context, VoidCallback? onPressed) buildSaveButton,
  Widget Function(BuildContext context) buildErrorContainer,
});

/// Shared showup detail body — owns [TextEditingController] lifecycle and
/// renders the common layout. Platform chrome lives in the enclosing Scaffold.
class ShowupDetailContent extends StatefulWidget {
  final ShowupDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function(String note) onSaveNote;
  final VoidCallback? onOpenPact;
  final ShowupStatusColors statusColors;
  final Color labelColor;
  final Color tileColor;
  final Color linkColor;
  final ShowupDetailSlots slots;

  const ShowupDetailContent({
    super.key,
    required this.state,
    required this.l10n,
    required this.onSaveNote,
    required this.statusColors,
    required this.labelColor,
    required this.tileColor,
    required this.linkColor,
    required this.slots,
    this.onOpenPact,
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
    if (showup == null) return const SizedBox.shrink();

    final l10n = widget.l10n;
    final scheduledDate = formatShowupDate(context, showup.scheduledAt);
    final scheduledTime = formatShowupTime(context, showup.scheduledAt);
    final durationMins = showup.duration.inMinutes;
    final isPending = showup.status == ShowupStatus.pending;
    final uiState = state.uiState;
    final statusColor = widget.statusColors.forUiState(uiState);
    final statusText = showupUiStateText(l10n, uiState);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.habitName ?? l10n.showupHabitDeleted,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            StatusBadge(text: statusText, color: statusColor),
          ],
        ),
        if (widget.onOpenPact != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            key: const Key('showup-pact-link'),
            onTap: widget.onOpenPact,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.showupViewPactDetails,
                  style: TextStyle(fontSize: 13, color: widget.linkColor),
                ),
                Icon(Icons.chevron_right, size: 13, color: widget.linkColor),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        DateRowTile(
          label: l10n.showupDetailScheduledAt,
          value: '$scheduledDate  $scheduledTime',
          valueColor: widget.labelColor,
          backgroundColor: widget.tileColor,
        ),
        const SizedBox(height: 8),
        DateRowTile(
          label: l10n.showupDetailDuration,
          value: l10n.showupDurationMinutes(durationMins),
          valueColor: widget.labelColor,
          backgroundColor: widget.tileColor,
        ),
        const SizedBox(height: 24),
        if (state.wasAutoFailed) ...[
          widget.slots.buildErrorContainer(context),
          const SizedBox(height: 16),
        ],
        if (isPending) ...[
          widget.slots.buildActionButtons(context, state),
          const SizedBox(height: 16),
        ],
        if (state.markError != null) ...[
          Text(
            l10n.showupMarkError,
            style: TextStyle(color: widget.statusColors.failed),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        SectionHeader(title: l10n.showupNoteLabel, labelColor: widget.labelColor),
        const SizedBox(height: 8),
        widget.slots.buildNoteField(context, _noteController),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _noteController,
          builder: (context, value, _) {
            final savedNote = state.showup?.note ?? '';
            final hasChanged = value.text != savedNote;
            final onPressed = (state.isSaving || !hasChanged) ? null : () => widget.onSaveNote(_noteController.text);
            return Align(
              alignment: Alignment.centerRight,
              child: widget.slots.buildSaveButton(context, onPressed),
            );
          },
        ),
        if (state.noteError != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.showupNoteError,
            style: TextStyle(color: widget.statusColors.failed),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
