import 'package:flutter/material.dart';
import 'package:habit_loop/features/showup/domain/showup_detail_state.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Material (Android) implementation of the showup detail screen.
class ShowupDetailPageAndroid extends StatefulWidget {
  final ShowupDetailState state;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;

  const ShowupDetailPageAndroid({
    super.key,
    required this.state,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
  });

  @override
  State<ShowupDetailPageAndroid> createState() =>
      _ShowupDetailPageAndroidState();
}

class _ShowupDetailPageAndroidState extends State<ShowupDetailPageAndroid> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.state.showup?.note ?? '',
    );
  }

  @override
  void didUpdateWidget(ShowupDetailPageAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller text when the showup note changes from outside (e.g., on
    // initial load). Only update if not currently editing to avoid cursor jumps.
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.showupDetailTitle)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
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

    final theme = Theme.of(context);
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
        // Habit name + status chip
        Row(
          children: [
            Expanded(
              child: Text(
                state.habitName ?? '',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(statusText),
              backgroundColor:
                  _statusColor(showup.status).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: _statusColor(showup.status),
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Info cards
        _InfoRow(label: l10n.showupDetailScheduledAt,
            value: '$scheduledDate  $scheduledTime'),
        const SizedBox(height: 8),
        _InfoRow(
          label: l10n.showupDetailDuration,
          value: l10n.showupDurationMinutes(durationMins),
        ),
        const SizedBox(height: 24),

        // Auto-fail notice
        if (state.wasAutoFailed) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.showupAutoFailed,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons (only for pending showups)
        if (isPending) ...[
          FilledButton(
            onPressed: state.isSaving ? null : onMarkDone,
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: state.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.markDone),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: state.isSaving ? null : onMarkFailed,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.markFailed),
          ),
          const SizedBox(height: 16),
        ],

        // Save error
        if (state.saveError != null) ...[
          Text(
            l10n.showupMarkError,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],

        // Note section (always visible)
        Text(
          l10n.showupNoteLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: noteController,
          maxLines: 4,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: l10n.showupNoteLabel,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: noteController,
          builder: (context, value, _) {
            final savedNote = state.showup?.note ?? '';
            final hasChanged = value.text != savedNote;
            return Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: (state.isSaving || !hasChanged)
                    ? null
                    : () => onSaveNote(noteController.text),
                child: Text(l10n.showupNoteSave),
              ),
            );
          },
        ),
        if (state.saveError != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.showupNoteError,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Color _statusColor(ShowupStatus status) {
    return switch (status) {
      ShowupStatus.pending => Colors.orange,
      ShowupStatus.done => Colors.green,
      ShowupStatus.failed => Colors.red,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
