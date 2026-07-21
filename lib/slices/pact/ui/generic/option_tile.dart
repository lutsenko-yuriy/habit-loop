import 'package:flutter/material.dart';
import 'package:habit_loop/theme/spacing.dart';

class OptionTile extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final IconData? selectedIcon;
  final IconData? unselectedIcon;
  final Color? unselectedIconColor;

  const OptionTile({
    super.key,
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
    this.selectedIcon,
    this.unselectedIcon,
    this.unselectedIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.1) : unselectedColor,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: selectedColor, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? (selectedIcon ?? Icons.check_circle) : (unselectedIcon ?? Icons.radio_button_unchecked),
              color:
                  isSelected ? selectedColor : (unselectedIconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(label),
          ],
        ),
      ),
    );
  }
}
