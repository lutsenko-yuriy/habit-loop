import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';

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
    return Padding(
      key: Key(keyPrefix),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(stepCount, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: Key('$keyPrefix-segment-$index'),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
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
          );
        }),
      ),
    );
  }
}
