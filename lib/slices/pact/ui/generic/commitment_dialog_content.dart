import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/spacing.dart';

// EXP-003 commitment dialog. Variants: button / checkbox / retype.
// Never pops the navigator — caller's responsibility.
class CommitmentDialogContent extends StatefulWidget {
  const CommitmentDialogContent({
    super.key,
    required this.variant,
    required this.habitName,
    required this.onAccept,
    required this.onDismiss,
  });

  final String variant;
  final String habitName;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  State<CommitmentDialogContent> createState() => _CommitmentDialogContentState();
}

class _CommitmentDialogContentState extends State<CommitmentDialogContent> {
  bool _checkboxChecked = false;
  late final TextEditingController _retypeController;

  @override
  void initState() {
    super.initState();
    _retypeController = TextEditingController();
  }

  @override
  void dispose() {
    _retypeController.dispose();
    super.dispose();
  }

  bool get _canAccept => switch (widget.variant) {
        'button' => true,
        'checkbox' => _checkboxChecked,
        'retype' => _retypeController.text.trim().toLowerCase() == widget.habitName.trim().toLowerCase(),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isButtonVariant = widget.variant == 'button';

    final acceptLabel = isButtonVariant ? l10n.commitmentAccept : l10n.createPactConfirm;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.commitmentStep,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          key: const Key('commitment-dialog-warning'),
          l10n.commitmentWarning,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.s16),
        if (widget.variant == 'checkbox')
          CheckboxListTile(
            key: const Key('commitment-dialog-checkbox'),
            value: _checkboxChecked,
            onChanged: (v) => setState(() => _checkboxChecked = v ?? false),
            title: Text(l10n.commitmentCheckboxLabel),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (widget.variant == 'retype') ...[
          Text(l10n.commitmentRetypePrompt),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            key: const Key('commitment-dialog-retype-field'),
            controller: _retypeController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.habitName,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        const SizedBox(height: AppSpacing.s8),
        FilledButton(
          key: const Key('commitment-dialog-accept'),
          onPressed: _canAccept ? widget.onAccept : null,
          child: Text(acceptLabel),
        ),
        const SizedBox(height: AppSpacing.s8),
        OutlinedButton(
          key: const Key('commitment-dialog-cancel'),
          onPressed: widget.onDismiss,
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
