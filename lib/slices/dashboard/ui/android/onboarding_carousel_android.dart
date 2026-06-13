import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/language_picker_dialog_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_scaffold.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_sign_in_controller.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/debug/ui/android/remote_config_overrides_page_android.dart';

class OnboardingCarouselAndroid extends ConsumerWidget {
  const OnboardingCarouselAndroid({super.key, required this.onCreatePact});

  final Future<void> Function() onCreatePact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final featureFlags = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: OnboardingCarouselScaffold(
          onCreatePact: onCreatePact,
          inactiveDotColor: Theme.of(context).colorScheme.outlineVariant,
          buildActions: (ctx, isSigningIn, isAnonymous) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: isSigningIn
                    ? null
                    : () {
                        ref.read(onboardingViewModelProvider.notifier).onCreatePactTapped();
                        unawaited(onCreatePact());
                      },
                child: Text(l10n.createPact),
              ),
              if (isAnonymous || isSigningIn) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: isSigningIn
                      ? null
                      : () async {
                          await OnboardingSignInController.signIn(
                            ref: ref,
                            context: ctx,
                            showFailureDialog: _showSignInFailureDialogAndroid(l10n),
                          );
                        },
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
                                color: Theme.of(ctx).colorScheme.primary,
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
              if (featureFlags.languageSelectionEnabled)
                TextButton(
                  onPressed: () => unawaited(openLanguagePicker(
                    context: ctx,
                    ref: ref,
                    showPicker: ({required context, required options, required currentOverride}) =>
                        showMaterialLanguagePicker(context, options, currentOverride, l10n),
                  )),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
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
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(builder: (_) => const RemoteConfigOverridesPageAndroid()),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                    textStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Remote Config'),
                ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> Function(BuildContext) _showSignInFailureDialogAndroid(AppLocalizations l10n) {
  return (BuildContext ctx) => showDialog<void>(
        context: ctx,
        builder: (c) => AlertDialog(
          content: Text(l10n.signInWithGoogleFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l10n.notNow),
            ),
          ],
        ),
      );
}
