import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/language_picker_dialog_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_widgets.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/debug/ui/android/remote_config_overrides_page_android.dart';

class OnboardingCarouselAndroid extends ConsumerStatefulWidget {
  const OnboardingCarouselAndroid({super.key, required this.onCreatePact});

  final Future<void> Function() onCreatePact;

  @override
  ConsumerState<OnboardingCarouselAndroid> createState() => _OnboardingCarouselAndroidState();
}

class _OnboardingCarouselAndroidState extends ConsumerState<OnboardingCarouselAndroid> {
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

    return Scaffold(
      appBar: null,
      body: SafeArea(
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
              inactiveDotColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: isSigningIn
                        ? null
                        : () {
                            ref.read(onboardingViewModelProvider.notifier).onCreatePactTapped();
                            unawaited(widget.onCreatePact());
                          },
                    child: Text(l10n.createPact),
                  ),
                  if (isAnonymous || isSigningIn) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isSigningIn ? null : () => unawaited(_onSignIn(context, l10n)),
                      child: isSigningIn
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(l10n.fetchingPacts),
                              ],
                            )
                          : Text(l10n.signInWithGoogle),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => unawaited(openLanguagePicker(
                      context: context,
                      ref: ref,
                      showPicker: ({required context, required options, required currentOverride}) =>
                          showMaterialLanguagePicker(context, options, currentOverride, l10n),
                    )),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(l10n.languagePickerTitle),
                  ),
                  // Debug/profile only — not visible in release builds.
                  // minimumSize: Size.zero + tapTargetSize keep the button
                  // height at ~14 pt (text only) so the slide column is not
                  // pushed out of view on small viewports.
                  if (kDebugMode || kProfileMode)
                    TextButton(
                      key: const Key('onboarding-remote-config-debug-button'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RemoteConfigOverridesPageAndroid(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        textStyle: const TextStyle(fontSize: 12),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Remote Config'),
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
      // linkWithGoogle() invalidates hasActivePactsProvider and fires dashboard
      // reload fire-and-forget.  Wait until the provider has resolved so the
      // dashboard is ready before we reveal it by resetting isSigningIn — this
      // prevents the carousel from disappearing while the dashboard is still
      // in its loading state.
      // The deadline guard (10 s) ensures the carousel is never permanently
      // frozen if hasActivePactsProvider stalls due to a database hang.
      await Future<void>.delayed(Duration.zero); // yield so Riverpod processes the invalidation
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (context.mounted && ref.read(hasActivePactsProvider).isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } on AuthLinkException {
      // Reset loading state before showing the error dialog so the
      // sign-in button reappears and the user can try again.
      if (context.mounted) ref.read(onboardingSignInLoadingProvider.notifier).state = false;
      if (!context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.signInWithGoogleFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.notNow),
            ),
          ],
        ),
      ));
    } finally {
      // Reset the flag — by this point hasActivePactsProvider has settled (or
      // timed out) so the dashboard is ready to display when the carousel unmounts.
      if (context.mounted) ref.read(onboardingSignInLoadingProvider.notifier).state = false;
    }
  }
}
