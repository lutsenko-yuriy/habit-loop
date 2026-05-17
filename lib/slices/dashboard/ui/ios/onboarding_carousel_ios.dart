import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_widgets.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/language_picker_dialog_ios.dart';

class OnboardingCarouselIos extends ConsumerStatefulWidget {
  const OnboardingCarouselIos({super.key, required this.onCreatePact});

  final Future<void> Function() onCreatePact;

  @override
  ConsumerState<OnboardingCarouselIos> createState() => _OnboardingCarouselIosState();
}

class _OnboardingCarouselIosState extends ConsumerState<OnboardingCarouselIos> {
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

    final isSigningIn = ref.watch(onboardingSignInLoadingProvider);

    return CupertinoPageScaffold(
      navigationBar: null,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: OnboardingSlide.slides.length,
                onPageChanged: (i) {
                  ref.read(onboardingViewModelProvider.notifier).onUserSwiped(i);
                },
                itemBuilder: (context, index) =>
                    OnboardingSlideWidget(slide: OnboardingSlide.slides[index], l10n: l10n),
              ),
            ),
            OnboardingDotsRow(
              currentIndex: vmIndex,
              count: OnboardingSlide.slides.length,
              inactiveDotColor: CupertinoColors.systemGrey4.resolveFrom(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoButton.filled(
                    onPressed: isSigningIn
                        ? null
                        : () {
                            ref.read(onboardingViewModelProvider.notifier).onCreatePactTapped();
                            unawaited(widget.onCreatePact());
                          },
                    child: Text(l10n.createPact),
                  ),
                  if (isAnonymous) ...[
                    const SizedBox(height: 12),
                    if (isSigningIn)
                      SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(),
                            const SizedBox(width: 8),
                            Text(
                              l10n.fetchingPacts,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    else
                      CupertinoButton(
                        onPressed: () => unawaited(_onSignIn(context, l10n)),
                        child: Text(l10n.signInWithGoogle),
                      ),
                  ],
                  const SizedBox(height: 4),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => unawaited(openLanguagePicker(
                      context: context,
                      ref: ref,
                      showPicker: ({required context, required options, required currentOverride}) =>
                          showCupertinoLanguagePicker(context, options, currentOverride, l10n),
                    )),
                    child: Text(
                      l10n.languagePickerTitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSignIn(BuildContext context, AppLocalizations l10n) async {
    ref.read(onboardingViewModelProvider.notifier).onSignInTapped();
    ref.read(onboardingSignInLoadingProvider.notifier).state = true;
    try {
      await ref.read(syncStatusViewModelProvider.notifier).linkWithGoogle();
      // linkWithGoogle() has already fired pullRemoteChanges + dashboard load.
      // The carousel stays visible (via onboardingSignInLoadingProvider = true)
      // until the dashboard_screen re-evaluates showCarousel in the next build.
    } on AuthLinkException {
      // Reset loading state before showing the error dialog so the
      // sign-in button reappears and the user can try again.
      if (context.mounted) ref.read(onboardingSignInLoadingProvider.notifier).state = false;
      if (!context.mounted) return;
      unawaited(showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text(l10n.signInWithGoogleFailed),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.notNow),
            ),
          ],
        ),
      ));
    } finally {
      // Always reset the flag so a successful sign-in + carousel disappearance
      // doesn't leave a stale true in the provider.
      if (context.mounted) ref.read(onboardingSignInLoadingProvider.notifier).state = false;
    }
  }
}
