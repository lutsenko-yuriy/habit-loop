import 'package:flutter/material.dart';
import 'package:habit_loop/theme/spacing.dart';

class DateRowTile extends StatelessWidget {
  final String label;
  final String? value;
  final Color valueColor;
  final Color backgroundColor;
  final double cornerRadius;
  final VoidCallback? onTap;

  const DateRowTile({
    super.key,
    required this.label,
    this.value,
    this.valueColor = Colors.black87,
    required this.backgroundColor,
    this.cornerRadius = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = value != null
        ? Row(
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: AppSpacing.s8),
              Text(value!, style: TextStyle(color: valueColor)),
            ],
          )
        : Text(label);

    Widget tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: content,
    );

    if (onTap != null) {
      tile = GestureDetector(onTap: onTap, child: tile);
    }
    return tile;
  }
}
