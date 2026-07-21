import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/habit_name_step.dart';
import 'package:habit_loop/theme/spacing.dart';

class HabitNameStepIos extends StatelessWidget {
  const HabitNameStepIos({
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
    return HabitNameStep(
      state: state,
      l10n: l10n,
      onHabitNameChanged: onHabitNameChanged,
      showCommitmentWarning: showCommitmentWarning,
      focusNode: focusNode,
      buildField: (ctx, l10n, controller, fn) => CupertinoTextField(
        key: const Key('pact-creation-habit-name-field'),
        placeholder: l10n.habitNameHint,
        controller: controller,
        focusNode: fn,
        autofocus: true,
        onChanged: onHabitNameChanged,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s14),
      ),
      buildWarning: (ctx, l10n) => Container(
        key: const Key('pact-creation-habit-name-commitment-rules'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(l10n.commitmentWarning, style: const TextStyle(fontSize: 14, height: 1.5)),
      ),
    );
  }
}
