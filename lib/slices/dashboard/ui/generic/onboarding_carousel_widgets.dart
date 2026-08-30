import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Shared page-indicator dots row for the onboarding carousel.
///
/// [inactiveDotColor] is platform-supplied so callers can pass
/// `CupertinoColors.systemGrey4.resolveFrom(context)` on iOS and
/// `Theme.of(context).colorScheme.outlineVariant` on Android.
class OnboardingDotsRow extends StatelessWidget {
  const OnboardingDotsRow({super.key, required this.currentIndex, required this.count, required this.inactiveDotColor});

  final int currentIndex;
  final int count;
  final Color inactiveDotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s16),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? HabitLoopColors.primary : inactiveDotColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Shared slide content widget for the onboarding carousel.
class OnboardingSlideWidget extends StatelessWidget {
  const OnboardingSlideWidget({super.key, required this.slide, required this.l10n, this.personalizedName});

  final OnboardingSlide slide;
  final AppLocalizations l10n;

  /// Resolved `personalizedNameProvider` value (HAB-232 WU6) — `null` when no
  /// name is on file or the kill-switch is off. Passed through to [slide]'s
  /// title/body builders; only slide 0 renders it.
  final String? personalizedName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SvgPicture.asset(slide.assetPath, width: 200, fit: BoxFit.contain),
            ),
          ),
          const Flexible(child: SizedBox(height: AppSpacing.s32)),
          Text(
            slide.title(l10n, personalizedName),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            // A long personalized name (HAB-232 WU6 audit finding) can push this past
            // the 1-2 lines the neutral copy always fit in — cap it defensively so it
            // never overflows the fixed-height carousel slot on a short viewport.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            slide.body(l10n, personalizedName),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
