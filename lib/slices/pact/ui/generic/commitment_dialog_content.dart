import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Platform-agnostic content widget for the EXP-003 commitment confirmation
/// dialog shown when the user taps "Create Pact" on the wizard summary screen.
///
/// Three variants are controlled by [variant]:
/// - `button` (control): commitment rules + a single "I accept" button.
/// - `checkbox` (variant A): commitment rules + checkbox that must be ticked
///   before the "Create pact" button is enabled.
/// - `retype` (variant B): commitment rules + text field where the user must
///   type their [habitName] (case-insensitive, trimmed) to enable "Create pact".
///
/// Calls [onAccept] when the user confirms and [onDismiss] when they cancel.
/// The widget never pops the navigator itself — that is the caller's
/// responsibility.
///
/// Rendered using Material widgets so it composes cleanly inside either a
/// Material [Dialog] (Android) or a [showDialog] call on iOS. Any containing
/// [CupertinoPageScaffold] should wrap this with a [Material] widget.
class CommitmentDialogContent extends StatefulWidget {
  const CommitmentDialogContent({
    super.key,
    required this.variant,
    required this.habitName,
    required this.onAccept,
    required this.onDismiss,
  });

  /// EXP-003 variant: `'button'` | `'checkbox'` | `'retype'`.
  final String variant;

  /// The habit name to match against in the `retype` variant.
  final String habitName;

  /// Called when the user confirms the commitment.
  final VoidCallback onAccept;

  /// Called when the user cancels / dismisses without confirming.
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

  /// Whether the accept/create button should be enabled for the current variant.
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
        // ── Title ──────────────────────────────────────────────────────────
        Text(
          l10n.commitmentStep,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // ── Commitment rules body ──────────────────────────────────────────
        Text(
          key: const Key('commitment-dialog-warning'),
          l10n.commitmentWarning,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),

        // ── Variant-specific confirmation UI ───────────────────────────────
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 8),

        // ── Action buttons ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('commitment-dialog-cancel'),
                onPressed: widget.onDismiss,
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('commitment-dialog-accept'),
                onPressed: _canAccept ? widget.onAccept : null,
                child: Text(acceptLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
