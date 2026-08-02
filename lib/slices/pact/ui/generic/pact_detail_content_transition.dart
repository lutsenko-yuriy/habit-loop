import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';

/// Direction of the chain-link navigation that produced a
/// [PactDetailContentTransition] key change (HAB-206 WU3) — determines which
/// way the outgoing/incoming content slides.
enum ChainNavigationDirection { toPredecessor, toSuccessor }

/// Duration of the main-content slide+fade transition. Shared with
/// [PactDetailScreen]'s `_isAnimating` guard so the guard stays set for the
/// full visual transition, not just the (often near-instant, thanks to
/// HAB-206 WU2's prefetch) underlying data reload.
const kChainNavigationTransitionDuration = Duration(milliseconds: 250);

/// Wraps pact-detail main content so that swapping to a chain-linked pact
/// (HAB-206) animates as a combined slide + fade instead of an instant swap.
/// Direction-aware: navigating to the predecessor slides the outgoing
/// content out to the right while it fades out, and slides the incoming
/// (predecessor's) content in from the left while it fades in. Navigating to
/// the successor mirrors this (out left, in from the right).
///
/// [transitionKey] identifies the pact currently shown — a change triggers
/// the transition, animated according to [direction]. The very first build
/// (no prior key to transition from) shows [child] immediately, unanimated.
class PactDetailContentTransition extends StatefulWidget {
  final Object transitionKey;
  final ChainNavigationDirection? direction;
  final Widget child;

  const PactDetailContentTransition({
    super.key,
    required this.transitionKey,
    required this.direction,
    required this.child,
  });

  @override
  State<PactDetailContentTransition> createState() => _PactDetailContentTransitionState();
}

class _PactDetailContentTransitionState extends State<PactDetailContentTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  // Snapshot of the content being animated out, captured at the moment
  // transitionKey changes. Cleared once the transition finishes so the old
  // subtree doesn't linger (and stops intercepting hit-testing, though it's
  // also wrapped in IgnorePointer for the duration it's shown).
  Widget? _outgoingChild;
  ChainNavigationDirection? _outgoingDirection;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kChainNavigationTransitionDuration);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant PactDetailContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionKey != oldWidget.transitionKey) {
      _outgoingChild = oldWidget.child;
      _outgoingDirection = widget.direction;
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTransitionEnd() {
    if (mounted && _outgoingChild != null) {
      setState(() => _outgoingChild = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoingChild;
    if (outgoing == null) {
      return widget.child;
    }

    // toPredecessor: outgoing slides right (+1), incoming enters from the
    // left. toSuccessor mirrors this: outgoing slides left (-1), incoming
    // enters from the right.
    final sign = _outgoingDirection == ChainNavigationDirection.toPredecessor ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        if (t >= 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onTransitionEnd());
        }
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - t,
                  child: FractionalTranslation(
                    translation: Offset(sign * t, 0),
                    child: outgoing,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: t,
                child: FractionalTranslation(
                  translation: Offset(-sign * (1 - t), 0),
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
