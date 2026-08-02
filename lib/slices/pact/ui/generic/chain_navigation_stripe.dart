import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_value_transition.dart';

/// Restyles the old Previous/Next Pact links (HAB-202) into a 2-slot
/// predecessor/successor chevron stripe (HAB-206 WU4).
///
/// Each slot crossfades independently via [AnimatedValueTransition] rather
/// than sliding as one spatial strip — a slot's identity can change on every
/// navigation regardless of direction (e.g. the predecessor slot shows the
/// old current pact right after a "next" tap), so per-slot old→new is
/// simpler than tracking a single pact's position across slots. A slot
/// appearing or disappearing (e.g. the chain head gaining a predecessor
/// slot) fades/slides in or out the same way, rather than popping.
class ChainNavigationStripe extends StatelessWidget {
  final Pact? predecessor;
  final Pact? successor;

  /// Outgoing snapshot, only set mid-transition.
  final Pact? previousPredecessor;
  final Pact? previousSuccessor;

  final SlideDirection? direction;
  final VoidCallback? onOpenPrevious;
  final VoidCallback? onOpenNext;

  const ChainNavigationStripe({
    super.key,
    this.predecessor,
    this.successor,
    this.previousPredecessor,
    this.previousSuccessor,
    this.direction,
    this.onOpenPrevious,
    this.onOpenNext,
  });

  @override
  Widget build(BuildContext context) {
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
    Widget label(Pact p) {
      final text = Flexible(child: Text(p.habitName, overflow: TextOverflow.ellipsis, style: AppTypography.caption));
      final chevron = Icon(leading ? Icons.chevron_left : Icons.chevron_right, size: 16);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: leading
            ? [chevron, const SizedBox(width: AppSpacing.s4), text]
            : [text, const SizedBox(width: AppSpacing.s4), chevron],
      );
    }

    TextButton outgoingButton(Pact p) => TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: null,
          child: label(p),
        );

    // The single persistent button for a slot that stays occupied across
    // this build — only its label crossfades (e.g. predecessor slot showing
    // the outgoing current pact's name right after a "next" tap).
    Widget persistentButton(Pact p) => TextButton(
          key: key,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: AnimatedValueTransition(
            direction: direction,
            previousChild: previousPact != null && previousPact.habitName != p.habitName ? label(previousPact) : null,
            child: label(p),
          ),
        );

    // Only trust presence/absence changes as a real transition when
    // [direction] is set — it's only non-null while an actual chain-link
    // swap is in flight, never on a screen's first load (where previousPact
    // is also null simply because there's no prior state to compare against).
    final isTransitioning = direction != null;

    if (pact != null && previousPact == null && isTransitioning) {
      // A neighbor that didn't exist a moment ago now does (e.g. the chain
      // head gaining a predecessor slot after moving one hop forward) —
      // fade/slide it in instead of popping it into place.
      return Flexible(
        child: AnimatedValueTransition(
          direction: direction,
          previousChild: const SizedBox.shrink(),
          child: persistentButton(pact),
        ),
      );
    }

    if (pact == null && previousPact != null && isTransitioning) {
      return Flexible(
        child: AnimatedValueTransition(
          direction: direction,
          previousChild: outgoingButton(previousPact),
          child: const SizedBox.shrink(),
        ),
      );
    }

    if (pact == null) return const SizedBox.shrink();

    return Flexible(child: persistentButton(pact));
  }
}
