import 'package:flutter/material.dart';
import 'package:habit_loop/theme/spacing.dart';

class OverrideBadge extends StatelessWidget {
  final bool isOverridden;

  const OverrideBadge({super.key, required this.isOverridden});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: Key(isOverridden ? 'override-badge' : 'default-badge'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: isOverridden ? cs.primary : cs.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOverridden ? 'OVERRIDE' : 'DEFAULT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isOverridden ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
