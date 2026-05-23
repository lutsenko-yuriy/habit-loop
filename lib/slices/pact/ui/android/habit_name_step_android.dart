import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// First wizard page on Android: the user enters their habit name.
///
/// The commitment rules are shown as body text so the user understands the
/// terms before proceeding.
class HabitNameStepAndroid extends StatefulWidget {
  const HabitNameStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onHabitNameChanged,
    this.showCommitmentWarning = true,
    this.focusNode,
  });

  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHabitNameChanged;

  /// Whether to show the commitment-rules warning box below the text field.
  /// Set to `false` in the edit wizard where the user already committed.
  final bool showCommitmentWarning;

  /// Optional [FocusNode] managed by the page container.
  ///
  /// The container requests focus on this node when the wizard is on the habit
  /// name page and unfocuses it when the user swipes to another page, keeping
  /// the software keyboard in sync with the active page.
  final FocusNode? focusNode;

  @override
  State<HabitNameStepAndroid> createState() => _HabitNameStepAndroidState();
}

class _HabitNameStepAndroidState extends State<HabitNameStepAndroid> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.habitName)
      ..selection = TextSelection.collapsed(offset: widget.state.habitName.length);
  }

  /// Syncs the controller text when the external state changes from outside the
  /// field (e.g. a programmatic clear), but skips the update when the user is
  /// typing so that cursor position is never reset mid-keystroke.
  @override
  void didUpdateWidget(covariant HabitNameStepAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.habitName != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.state.habitName,
        selection: TextSelection.collapsed(offset: widget.state.habitName.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          widget.l10n.habitNameLabel,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('pact-creation-habit-name-field'),
          controller: _controller,
          focusNode: widget.focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.l10n.habitNameHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: widget.onHabitNameChanged,
        ),
        if (widget.showCommitmentWarning) ...[
          const SizedBox(height: 24),
          Container(
            key: const Key('pact-creation-habit-name-commitment-rules'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.l10n.commitmentWarning,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
