import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';

typedef PactNoteSlots = ({
  Widget Function(BuildContext context, TextEditingController controller) buildNoteField,
  Widget Function(BuildContext context, VoidCallback? onPressed) buildSaveButton,
});

/// Shared stateful note section for inactive pact detail screens.
///
/// Owns the [TextEditingController] lifecycle and computes dirty state so
/// the Save button is only enabled when unsaved changes exist.
class PactNoteSection extends StatefulWidget {
  final String? savedNote;
  final bool isSaving;
  final Object? noteError;
  final Color labelColor;
  final Color errorColor;
  final Future<void> Function(String note) onSaveNote;
  final PactNoteSlots slots;

  const PactNoteSection({
    super.key,
    required this.savedNote,
    required this.isSaving,
    required this.noteError,
    required this.labelColor,
    required this.errorColor,
    required this.onSaveNote,
    required this.slots,
  });

  @override
  State<PactNoteSection> createState() => _PactNoteSectionState();
}

class _PactNoteSectionState extends State<PactNoteSection> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.savedNote ?? '');
  }

  @override
  void didUpdateWidget(PactNoteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNote = widget.savedNote ?? '';
    if (oldWidget.savedNote != widget.savedNote && _controller.text != newNote) {
      _controller.text = newNote;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.pactNoteLabel, labelColor: widget.labelColor),
        const SizedBox(height: 8),
        widget.slots.buildNoteField(context, _controller),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final savedNote = widget.savedNote ?? '';
            final hasChanged = value.text != savedNote;
            final onPressed = (widget.isSaving || !hasChanged) ? null : () => widget.onSaveNote(_controller.text);
            return Align(
              alignment: Alignment.centerRight,
              child: widget.slots.buildSaveButton(context, onPressed),
            );
          },
        ),
        if (widget.noteError != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.pactNoteError,
            style: TextStyle(color: widget.errorColor),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
