import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// First wizard page on iOS: the user enters their habit name.
///
/// The commitment rules are shown as body text so the user understands the
/// terms before proceeding.
class HabitNameStepIos extends StatefulWidget {
  const HabitNameStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onHabitNameChanged,
  });

  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHabitNameChanged;

  @override
  State<HabitNameStepIos> createState() => _HabitNameStepIosState();
}

class _HabitNameStepIosState extends State<HabitNameStepIos> {
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
  void didUpdateWidget(covariant HabitNameStepIos oldWidget) {
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          widget.l10n.habitNameLabel,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CupertinoTextField(
          key: const Key('pact-creation-habit-name-field'),
          placeholder: widget.l10n.habitNameHint,
          controller: _controller,
          onChanged: widget.onHabitNameChanged,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        const SizedBox(height: 24),
        Container(
          key: const Key('pact-creation-habit-name-commitment-rules'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.l10n.commitmentWarning,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
