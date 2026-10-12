import 'package:flutter/widgets.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

/// Crossfades+slides between the linked and empty checklist rows, matching
/// [AnimatedValueTransition]'s timing and 16px slide. Children must be keyed.
class PactChecklistTileSwitcher extends StatelessWidget {
  const PactChecklistTileSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kAnimatedValueTransitionDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          // The outgoing child animates in reverse; it ignores taps so stale buttons can't act.
          builder: (context, child) => IgnorePointer(
            ignoring: animation.status == AnimationStatus.reverse,
            child: Transform.translate(offset: Offset(16 * (1 - animation.value), 0), child: child),
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
