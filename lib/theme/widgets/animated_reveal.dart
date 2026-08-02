import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';

/// Shows or hides [child] via a single [AnimationController] driving both
/// the reported height and the opacity from the same value every frame, so
/// a sibling positioned after this widget shifts in lock-step with the fade
/// instead of the fade completing first and the shift happening afterwards
/// (the result of composing separate implicit animations, e.g.
/// `AnimatedSize` wrapping `AnimatedSwitcher` — its target size only changes
/// once the switched-out child is finally removed from the tree, at the end
/// of the fade, not throughout it).
///
/// Uses [Align.heightFactor] rather than a clipping widget (`AnimatedSize`,
/// `SizeTransition`) so the collapsing child keeps painting at its natural
/// size while the reported height shrinks — a widget painted after this one
/// in the same list will then visually overlap the still-fading content
/// instead of the transition looking like an opaque panel sliding over it.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.topCenter,
  });

  final bool visible;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Alignment alignment;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late CurvedAnimation _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

  @override
  void didUpdateWidget(covariant AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.curve != oldWidget.curve) {
      final oldAnimation = _animation;
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
      oldAnimation.dispose();
    }
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.visible != oldWidget.visible) {
      unawaited(widget.visible ? _controller.forward() : _controller.reverse());
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Clamp: a caller-supplied overshoot curve (e.g. easeOutBack) can push
        // the raw value outside [0, 1], which Opacity.opacity asserts against.
        final value = _animation.value.clamp(0.0, 1.0);
        if (value <= 0) return const SizedBox.shrink();
        return Align(
          alignment: widget.alignment,
          heightFactor: value,
          // Ignores hit-testing while collapsing (visible == false but value
          // still > 0 mid-fade-out) so a tap can't land on a control that's
          // visually on its way out and act on now-stale state — e.g. a
          // "Stop pact" tap landing during the ~250ms window after the pact
          // shown underneath has already changed. Taps are still allowed
          // while revealing (visible == true, value still climbing to 1) —
          // only the collapsing direction is unsafe, since only there does
          // the widget's meaning refer to a state that's already gone stale.
          child: IgnorePointer(ignoring: !widget.visible, child: Opacity(opacity: value, child: child)),
        );
      },
      child: widget.child,
    );
  }
}
