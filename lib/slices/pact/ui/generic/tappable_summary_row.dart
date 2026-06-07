import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';

class TappableSummaryRow extends StatelessWidget {
  final String tapKey;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;
  final Widget? divider;

  const TappableSummaryRow({
    super.key,
    required this.tapKey,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.onTap,
    this.divider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(tapKey),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: SummaryRow(label: label, value: value, labelColor: labelColor)),
              Icon(Icons.chevron_right, size: 18, color: labelColor),
            ],
          ),
          if (divider != null) divider!,
        ],
      ),
    );
  }
}
