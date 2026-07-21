import 'package:flutter/material.dart' show Icons, InkWell;
import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';
import 'package:habit_loop/theme/spacing.dart';

class TappableSummaryRow extends StatelessWidget {
  final String tapKey;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;
  final Widget? divider;

  // Use InkWell (Material ripple) instead of GestureDetector. Pass true on Android.
  final bool useInkWell;

  const TappableSummaryRow({
    super.key,
    required this.tapKey,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.onTap,
    this.divider,
    this.useInkWell = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Row(
          children: [
            Expanded(child: SummaryRow(label: label, value: value, labelColor: labelColor)),
            Icon(Icons.chevron_right, size: 18, color: labelColor),
          ],
        ),
        if (divider != null) divider!,
      ],
    );

    if (useInkWell) {
      return InkWell(
        key: Key(tapKey),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: content,
        ),
      );
    }
    return GestureDetector(
      key: Key(tapKey),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
