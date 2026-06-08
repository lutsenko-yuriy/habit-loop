import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';

class OnboardingSignInController {
  static Future<void> signIn({
    required WidgetRef ref,
    required BuildContext context,
    required Future<void> Function(BuildContext context) showFailureDialog,
  }) async {
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
      unawaited(showFailureDialog(context));
    } finally {
      // Reset the flag — by this point hasActivePactsProvider has settled so
      // the dashboard is ready to display when the carousel unmounts.
      if (context.mounted) ref.read(onboardingSignInLoadingProvider.notifier).state = false;
    }
  }
}
