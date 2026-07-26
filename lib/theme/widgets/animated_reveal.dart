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
  late Animation<double> _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

  @override
  void didUpdateWidget(covariant AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.curve != oldWidget.curve) {
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        if (value <= 0) return const SizedBox.shrink();
        return Align(
          alignment: widget.alignment,
          heightFactor: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
