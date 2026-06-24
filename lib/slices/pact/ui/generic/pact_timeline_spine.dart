import 'package:flutter/material.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

// Shared spine constants and painter for the golden-ratio timeline layout.
// Extracted here so iOS and Android pages stay in sync automatically.

const kTimelineSpineX = 22.0;

class TimelineSpinePainter extends CustomPainter {
  final Color dotColor;
  final Color? topDotColor;
  final bool isFirst;
  final bool isLast;
  final double dotRadius;
  // Pre-computed Y of the dot centre (from the top of the canvas).
  // Passed in by _SpineItem so it can be tuned per milestone type without
  // the painter needing to know about font sizes or padding conventions.
  final double dotCenterY;

  const TimelineSpinePainter({
    required this.dotColor,
    required this.topDotColor,
    required this.isFirst,
    required this.isLast,
    required this.dotRadius,
    required this.dotCenterY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;

    if (!isFirst && topDotColor != null) {
      const top = 0.0;
      final bottom = dotCenterY - dotRadius - 1;
      if (bottom > top) {
        canvas.drawLine(
          const Offset(kTimelineSpineX, top),
          Offset(kTimelineSpineX, bottom),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topDotColor!, dotColor],
            ).createShader(Rect.fromLTRB(0, top, 1, bottom))
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(kTimelineSpineX, dotCenterY + dotRadius + 1),
        Offset(kTimelineSpineX, size.height),
        Paint()
          ..color = dotColor
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(Offset(kTimelineSpineX, dotCenterY), dotRadius, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(TimelineSpinePainter old) =>
      old.dotColor != dotColor ||
      old.topDotColor != topDotColor ||
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.dotRadius != dotRadius ||
      old.dotCenterY != dotCenterY;
}

double timelineVerticalPadding(PactTimelineMilestone m) => switch (m) {
      PactCreatedMilestone _ || CurrentStateMilestone _ || PactConcludedMilestone _ => 14.0,
      ShowupGroupMilestone _ => 20.0,
      SingleShowupMilestone _ => 7.0,
      _ => 12.0,
    };
