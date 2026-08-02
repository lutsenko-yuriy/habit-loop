import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';

/// Which way [child] slides in relative to the outgoing value.
enum SlideDirection { forward, backward }

/// Default transition duration; also usable by callers that need to key an
/// external guard (e.g. a navigation lock) to the same window.
const kAnimatedValueTransitionDuration = Duration(milliseconds: 250);

// Fixed offset, not a fraction of the value's own width — content varies too
// widely in intrinsic width for a fraction to read consistently.
const _slideDistance = 16.0;

/// Crossfades+slides from [previousChild] to [child] whenever [previousChild]
/// is non-null; renders [child] directly, unanimated, when it's null.
///
/// [previousChild] is caller-supplied rather than inferred from a key diff,
/// since this widget's own Element may or may not survive a swap depending
/// on the caller's tree shape — both paths (fresh Element via [initState],
/// surviving Element via [didUpdateWidget]) funnel into the same adopt logic.
class AnimatedValueTransition extends StatefulWidget {
  final Widget? previousChild;
  final SlideDirection? direction;
  final Widget child;
  final Duration duration;

  const AnimatedValueTransition({
    super.key,
    required this.previousChild,
    required this.direction,
    required this.child,
    this.duration = kAnimatedValueTransitionDuration,
  });

  @override
  State<AnimatedValueTransition> createState() => _AnimatedValueTransitionState();
}

class _AnimatedValueTransitionState extends State<AnimatedValueTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  // Cleared once the transition finishes; also IgnorePointer-wrapped while shown.
  Widget? _outgoingChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _adoptPreviousChildIfAny(widget.previousChild);
  }

  @override
  void didUpdateWidget(covariant AnimatedValueTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the transition into having a previousChild starts a new animation
    // — a surviving Element gets re-supplied the same previousChild on every
    // rebuild for the rest of the transition window.
    if (widget.previousChild != null && oldWidget.previousChild == null) {
      _adoptPreviousChildIfAny(widget.previousChild);
    }
  }

  void _adoptPreviousChildIfAny(Widget? previousChild) {
    if (previousChild == null) return;
    _outgoingChild = previousChild;
    unawaited(_controller.forward(from: 0));
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

    // forward: outgoing slides left, incoming enters from the right.
    // backward mirrors this.
    final sign = widget.direction == SlideDirection.backward ? 1.0 : -1.0;

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
