import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// First wizard page on iOS: the user enters their habit name.
///
/// The commitment rules are shown as body text so the user understands the
/// terms before proceeding. The habit name input is always focused when this
/// page appears.
class HabitNameStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHabitNameChanged;

  const HabitNameStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onHabitNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.habitNameLabel,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CupertinoTextField(
          key: const Key('pact-creation-habit-name-field'),
          placeholder: l10n.habitNameHint,
          controller: TextEditingController(text: state.habitName)
            ..selection = TextSelection.collapsed(offset: state.habitName.length),
          onChanged: onHabitNameChanged,
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
            l10n.commitmentWarning,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
