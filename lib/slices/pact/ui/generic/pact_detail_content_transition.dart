import 'package:flutter/widgets.dart';

enum PactDetailTransitionDirection {
  toPredecessor,
  toSuccessor,
}

/// Direction-aware slide+fade transition used by in-place pact-chain swaps
/// (HAB-206 WU3). The keyed child changes only after the target pact has
/// already loaded, so the animation runs directly from old content to new
/// content instead of flashing a loading spinner in between.
class PactDetailContentTransition extends StatelessWidget {
  static const duration = Duration(milliseconds: 300);

  final String contentId;
  final String sectionId;
  final PactDetailTransitionDirection? direction;
  final Widget child;

  const PactDetailContentTransition({
    super.key,
    required this.contentId,
    required this.sectionId,
    required this.child,
    this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final keyedChild = KeyedSubtree(
      key: ValueKey('$contentId::$sectionId'),
      child: child,
    );

    if (direction == null) {
      return keyedChild;
    }

    final incomingOffset = switch (direction!) {
      PactDetailTransitionDirection.toPredecessor => const Offset(-0.18, 0),
      PactDetailTransitionDirection.toSuccessor => const Offset(0.18, 0),
    };
    final outgoingOffset = switch (direction!) {
      PactDetailTransitionDirection.toPredecessor => const Offset(0.12, 0),
      PactDetailTransitionDirection.toSuccessor => const Offset(-0.12, 0),
    };

    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey('$contentId::$sectionId');
          final phase = isIncoming
              ? CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                )
              : CurvedAnimation(
                  parent: ReverseAnimation(animation),
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
                );
          final opacity = isIncoming
              ? Tween<double>(begin: 0, end: 1).animate(phase)
              : Tween<double>(begin: 1, end: 0).animate(phase);
          final position = isIncoming
              ? Tween<Offset>(
                  begin: incomingOffset,
                  end: Offset.zero,
                ).animate(phase)
              : Tween<Offset>(
                  begin: Offset.zero,
                  end: outgoingOffset,
                ).animate(phase);

          return FadeTransition(
            opacity: opacity,
            child: SlideTransition(
              position: position,
              child: child,
            ),
          );
        },
        child: keyedChild,
      ),
    );
  }
}
