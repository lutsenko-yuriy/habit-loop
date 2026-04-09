import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Colors;
import 'package:habit_loop/features/showup/domain/showup_detail_state.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Cupertino (iOS) implementation of the showup detail screen.
class ShowupDetailPageIos extends StatefulWidget {
  final ShowupDetailState state;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;

  const ShowupDetailPageIos({
    super.key,
    required this.state,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
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
    if (oldWidget.state.showup?.note != widget.state.showup?.note &&
        _noteController.text != newNote) {
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
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.showupDetailTitle),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : state.loadError != null
                  ? Center(child: Text(state.loadError.toString()))
                  : _ShowupDetailContent(
                      state: state,
                      l10n: l10n,
                      noteController: _noteController,
                      onMarkDone: widget.onMarkDone,
                      onMarkFailed: widget.onMarkFailed,
                      onSaveNote: widget.onSaveNote,
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

  const _ShowupDetailContent({
    required this.state,
    required this.l10n,
    required this.noteController,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
  });

  @override
  Widget build(BuildContext context) {
    final showup = state.showup;
    assert(
      showup != null,
      '_ShowupDetailContent must only be shown after a successful load',
    );
    if (showup == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).toString();
    final scheduledDate = DateFormat.yMd(locale).format(showup.scheduledAt);
    final scheduledTime = DateFormat.jm(locale).format(showup.scheduledAt);
    final durationMins = showup.duration.inMinutes;
    final isPending = showup.status == ShowupStatus.pending;

    final statusText = switch (showup.status) {
      ShowupStatus.pending => l10n.showupPending,
      ShowupStatus.done => l10n.showupDone,
      ShowupStatus.failed => l10n.showupFailed,
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Habit name + status badge
        Row(
          children: [
            Expanded(
              child: Text(
                state.habitName ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(showup.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: _statusColor(showup.status),
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
            child: state.isSaving
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(l10n.markDone),
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
                onPressed: (state.isSaving || !hasChanged)
                    ? null
                    : () => onSaveNote(noteController.text),
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

  Color _statusColor(ShowupStatus status) {
    return switch (status) {
      ShowupStatus.pending => CupertinoColors.systemOrange,
      ShowupStatus.done => CupertinoColors.activeGreen,
      ShowupStatus.failed => CupertinoColors.destructiveRed,
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
