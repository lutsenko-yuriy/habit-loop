import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

class ShowupDurationStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<Duration> onChanged;

  const ShowupDurationStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentMinutes = state.showupDuration?.inMinutes ?? 10;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.showupDurationStep,
          style: AppTypography.wizardStepTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.showupDurationLabel),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text(
            l10n.showupDurationMinutes(currentMinutes),
            style: AppTypography.wizardHeroNumber,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 200,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: currentMinutes - 1,
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              onChanged(Duration(minutes: index + 1));
            },
            children: List.generate(
              120,
              (i) => Center(
                child: Text(l10n.showupDurationMinutes(i + 1)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
