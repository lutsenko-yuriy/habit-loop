import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';

/// Direction of the chain-link navigation that produced a value change
/// (HAB-206 WU3) — determines which way the outgoing/incoming value slides.
enum ChainNavigationDirection { toPredecessor, toSuccessor }

/// Duration of a value's slide+fade transition. Shared with
/// [PactDetailScreen]'s `_isAnimating` guard so the guard stays set for the
/// full visual transition, not just the (often near-instant, thanks to
/// HAB-206 WU2's prefetch) underlying data reload.
const kChainNavigationTransitionDuration = Duration(milliseconds: 250);

// Small, fixed offset rather than a fraction of the value's own width — the
// values this wraps (a habit name, a stat count, a formatted date) vary
// wildly in intrinsic width, and a fraction-of-self offset would make short
// values (e.g. a one-digit stat) barely move while long ones travel a long
// distance. A fixed distance keeps every value's motion visually consistent.
const _slideDistance = 16.0;

/// Wraps a single pact-detail value — the habit name, the status badge, a
/// stat tile's count, a timeline tile's date — so it animates as a small
/// combined slide + fade instead of an instant swap whenever a chain-link
/// navigation (HAB-206) changes which pact is shown.
///
/// [previousChild] is supplied by the caller — built from the *outgoing*
/// pact's data — only when this specific value actually differs between the
/// outgoing and incoming pact; `null` renders [child] directly, unanimated.
/// This is deliberately caller-driven rather than inferred from an internal
/// `didUpdateWidget` key diff: the content `ListView` this lives inside is
/// itself keyed by pact id (so integration-test scenarios can identify which
/// pact is currently shown), which means every value widget's Element is
/// torn down and recreated fresh on every chain-link swap — there is no
/// surviving State to diff an old vs. new build against. Passing the
/// snapshot in explicitly sidesteps that entirely: whatever value this
/// Element is first built with already carries everything it needs to
/// animate, right from `initState`.
///
/// Section headers, buttons, dividers, and other pact-independent chrome are
/// never wrapped in this, so they never animate.
class PactDetailAnimatedValue extends StatefulWidget {
  final Widget? previousChild;
  final ChainNavigationDirection? direction;
  final Widget child;

  const PactDetailAnimatedValue({
    super.key,
    required this.previousChild,
    required this.direction,
    required this.child,
  });

  @override
  State<PactDetailAnimatedValue> createState() => _PactDetailAnimatedValueState();
}

class _PactDetailAnimatedValueState extends State<PactDetailAnimatedValue> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  // Captured once, in initState — see the class doc for why this can't rely
  // on didUpdateWidget. Cleared once the transition finishes so the old
  // subtree doesn't linger (and stops intercepting hit-testing, though it's
  // also wrapped in IgnorePointer for the duration it's shown).
  Widget? _outgoingChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kChainNavigationTransitionDuration);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.previousChild != null) {
      _outgoingChild = widget.previousChild;
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
    final sign = widget.direction == ChainNavigationDirection.toPredecessor ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        if (t >= 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onTransitionEnd());
        }
        return Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(sign * t * _slideDistance, 0),
                  child: outgoing,
                ),
              ),
            ),
            Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(-sign * (1 - t) * _slideDistance, 0),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
