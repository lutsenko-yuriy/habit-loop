import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color labelColor;

  const SectionHeader({super.key, required this.title, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: labelColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
