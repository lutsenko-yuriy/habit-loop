import 'package:flutter/widgets.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

/// Plain crossfade between the linked and empty checklist rows, on the page's
/// usual transition duration. Children must be keyed.
class PactChecklistTileSwitcher extends StatelessWidget {
  const PactChecklistTileSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kAnimatedValueTransitionDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        // The outgoing child animates in reverse; it ignores taps so stale buttons can't act.
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) =>
              IgnorePointer(ignoring: animation.status == AnimationStatus.reverse, child: child),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
