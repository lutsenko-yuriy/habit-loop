import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Theme;
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart' show ShowupUiState;

/// Cupertino (iOS) implementation of the showup detail screen.
class ShowupDetailPageIos extends StatefulWidget {
  final ShowupDetailState state;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;

  /// Called when the user taps the habit name to open the parent pact detail.
  /// Null when the pact has been deleted (habitName is also null in that case).
  final VoidCallback? onOpenPact;

  const ShowupDetailPageIos({
    super.key,
    required this.state,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
    this.onOpenPact,
  });

  @override
  State<ShowupDetailPageIos> createState() => _ShowupDetailPageIosState();
}

class _ShowupDetailPageIosState extends State<ShowupDetailPageIos> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.state.showup?.note ?? '',
    );
  }

  @override
  void didUpdateWidget(ShowupDetailPageIos oldWidget) {
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
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.showupDetailTitle),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : state.isShowupNotFound
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.showupNotFound,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(AppLocalizations.of(context)!.back),
                          ),
                        ],
                      ),
                    )
                  : state.loadError != null
                      ? Center(child: Text(state.loadError.toString()))
                      : _ShowupDetailContent(
                          state: state,
                          l10n: l10n,
                          noteController: _noteController,
                          onMarkDone: widget.onMarkDone,
                          onMarkFailed: widget.onMarkFailed,
                          onSaveNote: widget.onSaveNote,
                          onOpenPact: widget.onOpenPact,
                        ),
        ),
      ),
    );
  }
}

class _ShowupDetailContent extends StatelessWidget {
  final ShowupDetailState state;
  final AppLocalizations l10n;
  final TextEditingController noteController;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;
  final VoidCallback? onOpenPact;

  const _ShowupDetailContent({
    required this.state,
    required this.l10n,
    required this.noteController,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
    this.onOpenPact,
  });

  @override
  Widget build(BuildContext context) {
    final showup = state.showup;
    assert(
      showup != null,
      '_ShowupDetailContent must only be shown after a successful load',
    );
    if (showup == null) return const SizedBox.shrink();

    final scheduledDate = formatShowupDate(context, showup.scheduledAt);
    final scheduledTime = formatShowupTime(context, showup.scheduledAt);
    final durationMins = showup.duration.inMinutes;
    final isPending = showup.status == ShowupStatus.pending;

    // uiState is derived in ShowupDetailViewModel.load() using the injectable
    // showupDetailNowProvider clock — not DateTime.now() — so it is testable
    // and consistent with the auto-fail outcome computed at screen open time.
    final uiState = state.uiState;
    final statusText = showupUiStateText(l10n, uiState);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Habit name + status badge
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onOpenPact,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.habitName ?? l10n.showupHabitDeleted,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: onOpenPact != null
                              ? CupertinoColors.activeBlue.resolveFrom(context)
                              : null,
                        ),
                      ),
                    ),
                    if (onOpenPact != null)
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(uiState).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: _statusColor(uiState),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Info rows
        _InfoRow(
          label: l10n.showupDetailScheduledAt,
          value: '$scheduledDate  $scheduledTime',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: l10n.showupDetailDuration,
          value: l10n.showupDurationMinutes(durationMins),
        ),
        const SizedBox(height: 24),

        // Auto-fail notice
        if (state.wasAutoFailed) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CupertinoColors.systemRed.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              l10n.showupAutoFailed,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons (only for pending showups)
        if (isPending) ...[
          CupertinoButton.filled(
            onPressed: state.isSaving ? null : onMarkDone,
            child: state.isSaving ? const CupertinoActivityIndicator(color: Colors.white) : Text(l10n.markDone),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            onPressed: state.isSaving ? null : onMarkFailed,
            child: Text(
              l10n.markFailed,
              style: const TextStyle(color: CupertinoColors.destructiveRed),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Mark error (shown above the note section)
        if (state.markError != null) ...[
          Text(
            l10n.showupMarkError,
            style: const TextStyle(color: CupertinoColors.destructiveRed),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],

        // Note section (always visible)
        _SectionHeader(title: l10n.showupNoteLabel),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: noteController,
          placeholder: l10n.showupNoteLabel,
          maxLines: 4,
          minLines: 2,
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: noteController,
          builder: (context, value, _) {
            final savedNote = state.showup?.note ?? '';
            final hasChanged = value.text != savedNote;
            return Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: (state.isSaving || !hasChanged) ? null : () => onSaveNote(noteController.text),
                child: Text(l10n.showupNoteSave),
              ),
            );
          },
        ),
        if (state.noteError != null) ...[
          Text(
            l10n.showupNoteError,
            style: const TextStyle(color: CupertinoColors.destructiveRed),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Color _statusColor(ShowupUiState state) {
    return switch (state) {
      ShowupUiState.planned => CupertinoColors.systemGrey,
      ShowupUiState.waitingForStart => CupertinoColors.systemYellow,
      ShowupUiState.active => CupertinoColors.systemOrange,
      ShowupUiState.done => CupertinoColors.activeGreen,
      ShowupUiState.failed => CupertinoColors.destructiveRed,
    };
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

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
            value,
            style: const TextStyle(color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }
}
