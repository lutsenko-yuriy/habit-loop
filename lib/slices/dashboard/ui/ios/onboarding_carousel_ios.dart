import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_carousel_scaffold.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_sign_in_controller.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/language_picker_dialog_ios.dart';
import 'package:habit_loop/slices/debug/ui/ios/remote_config_overrides_page_ios.dart';
import 'package:habit_loop/theme/spacing.dart';

class OnboardingCarouselIos extends ConsumerWidget {
  const OnboardingCarouselIos({super.key, required this.onCreatePact});

  final Future<void> Function() onCreatePact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final featureFlags = ref.watch(featureFlagsProvider);

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: null,
      child: SafeArea(
        child: OnboardingCarouselScaffold(
          onCreatePact: onCreatePact,
          inactiveDotColor: CupertinoColors.systemGrey4.resolveFrom(context),
          buildActions: (ctx, isSigningIn, isAnonymous) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoButton.filled(
                onPressed: isSigningIn
                    ? null
                    : () {
                        ref.read(onboardingViewModelProvider.notifier).onCreatePactTapped();
                        unawaited(onCreatePact());
                      },
                child: Text(l10n.createPact),
              ),
              if (featureFlags.networkSyncEnabled && (isAnonymous || isSigningIn)) ...[
                const SizedBox(height: AppSpacing.s12),
                CupertinoButton(
                  onPressed: isSigningIn
                      ? null
                      : () async {
                          await OnboardingSignInController.signIn(
                            ref: ref,
                            context: ctx,
                            showFailureDialog: _showSignInFailureDialogIos(l10n),
                          );
                        },
                  child: isSigningIn
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(),
                            const SizedBox(width: AppSpacing.s8),
                            Text(l10n.fetchingPacts),
                          ],
                        )
                      : Text(l10n.signInWithGoogle),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              if (featureFlags.languageSelectionEnabled)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => unawaited(openLanguagePicker(
                    context: ctx,
                    ref: ref,
                    showPicker: ({required context, required options, required currentOverride}) =>
                        showCupertinoLanguagePicker(context, options, currentOverride, l10n),
                  )),
                  child: Text(
                    l10n.languagePickerTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                    ),
                  ),
                ),
              // Debug/profile only — not visible in release builds.
              // minimumSize: Size.zero keeps the button height at ~14 pt (text only)
              // so it doesn't push the slide column out of view on small viewports.
              if (kDebugMode || kProfileMode)
                CupertinoButton(
                  key: const Key('onboarding-remote-config-debug-button'),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(ctx)
                      .push(CupertinoPageRoute<void>(builder: (_) => const RemoteConfigOverridesPageIos()))
                      // ignore: use_build_context_synchronously — context.mounted checked inside
                      .then((_) {
                    if (ctx.mounted) ref.invalidate(featureFlagsProvider);
                  }),
                  child: Text(
                    'Remote Config',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + AppSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> Function(BuildContext) _showSignInFailureDialogIos(AppLocalizations l10n) {
  return (BuildContext ctx) => showCupertinoDialog<void>(
        context: ctx,
        builder: (c) => CupertinoAlertDialog(
          content: Text(l10n.signInWithGoogleFailed),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c),
              child: Text(l10n.notNow),
            ),
          ],
        ),
      );
}
