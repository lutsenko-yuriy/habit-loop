import 'package:flutter/widgets.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';
import 'package:habit_loop/theme/spacing.dart';

const double _stepTapTargetMinSize = 48;

class WizardStepIndicator extends StatelessWidget {
  final WizardStyle style;
  final int currentIndex;
  final int stepCount;
  final ValueChanged<int> onStepTapped;

  // Used as Key on the outer Padding and Key('$keyPrefix-segment-$N') on each segment.
  final String keyPrefix;

  const WizardStepIndicator({
    super.key,
    required this.style,
    required this.currentIndex,
    required this.stepCount,
    required this.onStepTapped,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      key: Key(keyPrefix),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      child: Row(
        children: List.generate(stepCount, (index) {
          return Expanded(
            child: Semantics(
              label: l10n.wizardStepIndicatorLabel(index + 1, stepCount),
              selected: index == currentIndex,
              button: true,
              child: GestureDetector(
                onTap: () => onStepTapped(index),
                behavior: HitTestBehavior.opaque,
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _stepTapTargetMinSize),
                    child: Center(
                      child: Container(
                        key: Key('$keyPrefix-segment-$index'),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: index < currentIndex
                              ? style.pastStepColor
                              : index == currentIndex
                                  ? style.activeStepColor
                                  : style.inactiveStepColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
