import 'package:flutter/material.dart';

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
    this.valueColor = Colors.grey,
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
              const SizedBox(width: 8),
              Text(value!, style: TextStyle(color: valueColor)),
            ],
          )
        : Text(label);

    Widget tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
