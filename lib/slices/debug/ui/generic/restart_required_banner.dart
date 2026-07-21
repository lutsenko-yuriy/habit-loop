import 'package:flutter/material.dart';
import 'package:habit_loop/theme/spacing.dart';

// debug_backend takes effect only after a restart — banner makes that visible.
class RestartRequiredBanner extends StatelessWidget {
  final Color color;
  final IconData? icon;

  const RestartRequiredBanner({super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: AppSpacing.s8),
          const Expanded(
            child: Text(
              'debug_backend changed — restart the app to apply',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
