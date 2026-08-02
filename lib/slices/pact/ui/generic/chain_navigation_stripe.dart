import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

/// Restyles the old Previous/Next Pact links (HAB-202) into a 3-slot
/// [predecessor, current, successor] carousel (HAB-206 WU4).
///
/// Each slot crossfades independently via [AnimatedValueTransition] rather
/// than sliding as one spatial strip — a slot's identity can change on every
/// navigation regardless of direction (e.g. the predecessor slot shows the
/// old current pact right after a "next" tap), so per-slot old→new is
/// simpler than tracking a single pact's position across slots.
class ChainNavigationStripe extends StatelessWidget {
  final Pact current;
  final Pact? predecessor;
  final Pact? successor;

  /// Outgoing snapshot, only set mid-transition.
  final Pact? previousCurrent;
  final Pact? previousPredecessor;
  final Pact? previousSuccessor;

  final SlideDirection? direction;
  final VoidCallback? onOpenPrevious;
  final VoidCallback? onOpenNext;

  const ChainNavigationStripe({
    super.key,
    required this.current,
    this.predecessor,
    this.successor,
    this.previousCurrent,
    this.previousPredecessor,
    this.previousSuccessor,
    this.direction,
    this.onOpenPrevious,
    this.onOpenNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _chevronSlot(
          key: const Key('pact-detail-previous-pact-link'),
          pact: predecessor,
          previousPact: previousPredecessor,
          onTap: onOpenPrevious,
          leading: true,
        ),
        Flexible(
          child: AnimatedValueTransition(
            key: const Key('pact-detail-current-pact-chip'),
            direction: direction,
            previousChild: previousCurrent != null && previousCurrent!.habitName != current.habitName
                ? _currentChip(theme, previousCurrent!.habitName)
                : null,
            child: _currentChip(theme, current.habitName),
          ),
        ),
        _chevronSlot(
          key: const Key('pact-detail-next-pact-link'),
          pact: successor,
          previousPact: previousSuccessor,
          onTap: onOpenNext,
          leading: false,
        ),
      ],
    );
  }

  Widget _chevronSlot({
    required Key key,
    required Pact? pact,
    required Pact? previousPact,
    required VoidCallback? onTap,
    required bool leading,
  }) {
    if (pact == null) return const SizedBox.shrink();

    Widget label(Pact p) {
      final text = Flexible(child: Text(p.habitName, overflow: TextOverflow.ellipsis, style: AppTypography.caption));
      final chevron = Icon(leading ? Icons.chevron_left : Icons.chevron_right, size: 16);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: leading ? [chevron, const SizedBox(width: AppSpacing.s4), text] : [text, const SizedBox(width: AppSpacing.s4), chevron],
      );
    }

    return Flexible(
      child: TextButton(
        key: key,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: AnimatedValueTransition(
          direction: direction,
          previousChild: previousPact != null && previousPact.habitName != pact.habitName ? label(previousPact) : null,
          child: label(pact),
        ),
      ),
    );
  }

  Widget _currentChip(ThemeData theme, String habitName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        habitName,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
