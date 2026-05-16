import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

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
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
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
  const OnboardingSlideWidget({super.key, required this.slide, required this.l10n});

  final OnboardingSlide slide;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(slide.assetPath, width: 200, height: 160),
          const SizedBox(height: 32),
          Text(
            slide.title(l10n),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.body(l10n),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
