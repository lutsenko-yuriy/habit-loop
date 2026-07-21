import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_widgets.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Shared onboarding carousel body — owns [PageController] lifecycle and
/// the [ref.listen] page-animation hook. Platform scaffold chrome lives in
/// the enclosing [CupertinoPageScaffold] / [Scaffold].
class OnboardingCarouselScaffold extends ConsumerStatefulWidget {
  final Future<void> Function() onCreatePact;
  final Color inactiveDotColor;

  /// Called during build with the current [isSigningIn] and [isAnonymous]
  /// values. Should return the Column of platform action buttons.
  final Widget Function(BuildContext context, bool isSigningIn, bool isAnonymous) buildActions;

  const OnboardingCarouselScaffold({
    super.key,
    required this.onCreatePact,
    required this.inactiveDotColor,
    required this.buildActions,
  });

  @override
  ConsumerState<OnboardingCarouselScaffold> createState() => _OnboardingCarouselScaffoldState();
}

class _OnboardingCarouselScaffoldState extends ConsumerState<OnboardingCarouselScaffold> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vmIndex = ref.watch(onboardingViewModelProvider);
    final auth = ref.watch(authStateChangesProvider).valueOrNull;
    final isAnonymous = auth?.isAnonymous ?? true;
    final isSigningIn = ref.watch(onboardingSignInLoadingProvider);

    ref.listen<int>(onboardingViewModelProvider, (_, next) {
      if (!_controller.hasClients) return;
      if (_controller.page?.round() != next) {
        unawaited(_controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ));
      }
    });

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: OnboardingSlide.slides.length,
            onPageChanged: (i) {
              ref.read(onboardingViewModelProvider.notifier).onUserSwiped(i);
            },
            itemBuilder: (context, index) => OnboardingSlideWidget(
              slide: OnboardingSlide.slides[index],
              l10n: l10n,
            ),
          ),
        ),
        OnboardingDotsRow(
          currentIndex: vmIndex,
          count: OnboardingSlide.slides.length,
          inactiveDotColor: widget.inactiveDotColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: widget.buildActions(context, isSigningIn, isAnonymous),
        ),
      ],
    );
  }
}
