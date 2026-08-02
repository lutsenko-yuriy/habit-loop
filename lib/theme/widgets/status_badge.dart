import 'package:flutter/material.dart';
import 'package:habit_loop/theme/spacing.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  /// Forces the badge to this width instead of sizing to [text]'s own
  /// intrinsic width. Used on pact detail (HAB-206 WU3) so the badge doesn't
  /// visibly resize (and shift the whole Row's layout) while crossfading
  /// between two different status labels — `null` elsewhere, unchanged
  /// auto-sizing behavior.
  final double? width;

  const StatusBadge({super.key, required this.text, required this.color, this.width});

  static const textStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);

  /// The widest this badge would ever need to be for any of [texts] (e.g.
  /// every possible status label), so a caller can pin every instance to the
  /// same [width] regardless of which text it's currently showing.
  static double widestOf(BuildContext context, Iterable<String> texts) {
    var widest = 0.0;
    for (final text in texts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    return widest + AppSpacing.s10 * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: textStyle.copyWith(color: color),
      ),
    );
  }
}
