import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/habit_name_step.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

class HabitNameStepAndroid extends StatelessWidget {
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
  final bool showCommitmentWarning;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HabitNameStep(
      state: state,
      l10n: l10n,
      onHabitNameChanged: onHabitNameChanged,
      showCommitmentWarning: showCommitmentWarning,
      focusNode: focusNode,
      titleStyle: theme.textTheme.headlineSmall,
      buildField: (ctx, l10n, controller, fn) => TextField(
        key: const Key('pact-creation-habit-name-field'),
        controller: controller,
        focusNode: fn,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.habitNameHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onHabitNameChanged,
      ),
      buildWarning: (ctx, l10n) {
        final t = Theme.of(ctx);
        return Container(
          key: const Key('pact-creation-habit-name-commitment-rules'),
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: t.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: AppTypography.bodyRelaxed.copyWith(color: t.colorScheme.onTertiaryContainer),
          ),
        );
      },
    );
  }
}
