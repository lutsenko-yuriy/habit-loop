import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_slide.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

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

    // Animate the controller when the view model advances (timer-driven).
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
                itemBuilder: (context, index) => _SlideWidget(slide: OnboardingSlide.slides[index], l10n: l10n),
              ),
            ),
            _DotsRow(currentIndex: vmIndex, count: OnboardingSlide.slides.length),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoButton.filled(
                    onPressed: () {
                      ref.read(onboardingViewModelProvider.notifier).onCreatePactTapped();
                      unawaited(widget.onCreatePact());
                    },
                    child: Text(l10n.createPact),
                  ),
                  if (isAnonymous) ...[
                    const SizedBox(height: 12),
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
                          _showCupertinoLanguagePicker(context, options, currentOverride, l10n),
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
    try {
      await ref.read(syncStatusViewModelProvider.notifier).linkWithGoogle();
    } on AuthLinkException {
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
    }
  }
}

Future<Locale?> _showCupertinoLanguagePicker(
  BuildContext context,
  List<({String label, Locale? locale})> options,
  Locale? currentOverride,
  AppLocalizations l10n,
) async {
  String prefixed(String label, Locale? locale) {
    final isSelected = locale == null ? currentOverride == null : currentOverride?.languageCode == locale.languageCode;
    return isSelected ? '✓ $label' : label;
  }

  final result = await showCupertinoModalPopup<(bool, Locale?)>(
    context: context,
    // ignore: use_build_context_synchronously
    builder: (ctx) => CupertinoActionSheet(
      title: Text(l10n.languagePickerTitle),
      actions: options.map((opt) {
        return CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, (opt.locale == null, opt.locale)),
          child: Text(prefixed(opt.label, opt.locale)),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (result == null) return null;
  final (isSystem, locale) = result;
  return isSystem ? null : locale;
}

class _DotsRow extends StatelessWidget {
  const _DotsRow({required this.currentIndex, required this.count});

  final int currentIndex;
  final int count;

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
            color: active ? HabitLoopColors.primary : CupertinoColors.systemGrey4.resolveFrom(context),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _SlideWidget extends StatelessWidget {
  const _SlideWidget({required this.slide, required this.l10n});

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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.body(l10n),
            style: const TextStyle(fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
