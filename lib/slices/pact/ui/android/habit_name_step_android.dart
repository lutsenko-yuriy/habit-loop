import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// First wizard page on Android: the user enters their habit name.
///
/// The commitment rules are shown as body text so the user understands the
/// terms before proceeding.
class HabitNameStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHabitNameChanged;

  const HabitNameStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onHabitNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.habitNameLabel,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('pact-creation-habit-name-field'),
          controller: TextEditingController(text: state.habitName)
            ..selection = TextSelection.collapsed(offset: state.habitName.length),
          decoration: InputDecoration(
            hintText: l10n.habitNameHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: onHabitNameChanged,
        ),
        const SizedBox(height: 24),
        Container(
          key: const Key('pact-creation-habit-name-commitment-rules'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
