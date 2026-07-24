import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, CupertinoPageRoute, showCupertinoDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/about/ui/generic/about_screen.dart';
import 'package:habit_loop/slices/dashboard/analytics/dashboard_screens.dart';
import 'package:habit_loop/slices/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  bool _creatingPact = false;

  // Guards one-time markOnboardingPassed write — prevents re-entrant build calls from firing it twice.
  bool _onboardingMarkedThisSession = false;

  // Midnight-normalised date of the last load; enables midnight-crossing detection.
  DateTime? _lastLoadDate;

  @override
  void initState() {
    super.initState();
    // ref.read is safe in initState; captures date synchronously so _lastLoadDate
    // is never null when didChangeAppLifecycleState fires.
    _lastLoadDate = _dateOnly(ref.read(todayProvider));
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
        );
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
        unawaited(ref.read(pactListViewModelProvider.notifier).load());
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _dateOnly(ref.read(todayProvider));
    if (today == _lastLoadDate) return;

    // Update guard first so re-entrant resume during the async load below is no-op'd.
    _lastLoadDate = today;
    ref.invalidate(todayProvider);
    ref.invalidate(hasActivePactsProvider);
    unawaited(
      ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
    );
    unawaited(ref.read(dashboardViewModelProvider.notifier).load());
    unawaited(ref.read(pactListViewModelProvider.notifier).load());
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardViewModelProvider);
    final hasActivePacts = ref.watch(hasActivePactsProvider);
    // ignore: avoid_print
    print(
      'DIAG DashboardScreen.build at ${DateTime.now().toIso8601String()} '
      'isLoading=${state.isLoading} pactNames=${state.pactNames} '
      'hasActivePacts=${hasActivePacts.asData?.value} '
      'isCurrent=${ModalRoute.of(context)?.isCurrent} '
      'animStatus=${ModalRoute.of(context)?.animation?.status}',
    );

    void onDaySelected(int index) {
      ref.read(dashboardViewModelProvider.notifier).selectDay(index);
    }

    Future<void> navigateToPactCreation() async {
      ref.invalidate(pactCreationViewModelProvider);
      if (!context.mounted) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => const PactCreationScreen(),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PactCreationScreen(),
          ),
        );
      }
      if (context.mounted) {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
        );
        // hasActivePactsProvider and the dashboard reload are already handled by
        // dashboardRefreshSignalProvider's listener when a pact was actually
        // created (bumped from PactCreationScreen before it pops) — invalidating
        // and reloading again here raced with that listener's own invalidation
        // of the same FutureProvider.
        unawaited(ref.read(pactListViewModelProvider.notifier).load());
      }
    }

    Future<void> onCreatePact() async {
      if (_creatingPact) return;
      _creatingPact = true;
      try {
        final pactRepo = ref.read(pactRepositoryProvider);
        final l10n = AppLocalizations.of(context)!;
        final activePacts = await pactRepo.getActivePacts();
        if (!context.mounted) return;
        final maxActivePacts = ref.read(remoteConfigServiceProvider).getInt('max_active_pacts');
        if (activePacts.length >= maxActivePacts) {
          final bool confirmed;
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            confirmed = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: Text(l10n.tooManyPactsTitle),
                    content: Text(l10n.tooManyPactsBody(maxActivePacts)),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.tooManyPactsConfirm),
                      ),
                    ],
                  ),
                ) ??
                false;
          } else {
            confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.tooManyPactsTitle),
                    content: Text(l10n.tooManyPactsBody(maxActivePacts)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.tooManyPactsConfirm),
                      ),
                    ],
                  ),
                ) ??
                false;
          }
          if (!confirmed) return;
        }
        await navigateToPactCreation();
      } catch (_) {
        // getActivePacts failed — proceed without the guard so the user
        // can still create a pact.
        if (context.mounted) await navigateToPactCreation();
      } finally {
        _creatingPact = false;
      }
    }

    Future<void> navigateToAbout() async {
      if (!context.mounted) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => const AboutScreen(),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AboutScreen(),
          ),
        );
      }
      if (context.mounted) {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
        );
      }
    }

    Future<void> onShowupTapped(String showupId) async {
      if (!context.mounted) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => ShowupDetailScreen(showupId: showupId),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShowupDetailScreen(showupId: showupId),
          ),
        );
      }
      if (context.mounted) {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
        );
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
        unawaited(ref.read(pactListViewModelProvider.notifier).load());
      }
    }

    final authState = ref.watch(authStateChangesProvider).valueOrNull;
    final isAnonymous = authState?.isAnonymous ?? true;
    final isSigningIn = ref.watch(onboardingSignInLoadingProvider);

    final onboardingService = ref.read(onboardingPreferenceServiceProvider);
    final onboardingPassed = onboardingService.isOnboardingPassed;

    final hasPacts = hasActivePacts.valueOrNull ?? false;
    final isNewUser = isAnonymous && !hasPacts;

    // !onboardingPassed short-circuits on cold start so AsyncLoading never causes a carousel flash.
    // isSigningIn keeps carousel visible during pullRemoteChanges after Google sign-in.
    final showCarousel = !onboardingPassed && (isNewUser || isSigningIn);

    // Deferred to post-frame so build() stays a pure function of state.
    if (!showCarousel && !_onboardingMarkedThisSession) {
      _onboardingMarkedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(onboardingService.markOnboardingPassed());
      });
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return DashboardPageIos(
        state: state,
        hasPacts: hasPacts,
        showCarousel: showCarousel,
        onDaySelected: onDaySelected,
        onCreatePact: onCreatePact,
        onShowupTapped: onShowupTapped,
        onAbout: navigateToAbout,
      );
    }
    return DashboardPageAndroid(
      state: state,
      hasPacts: hasPacts,
      showCarousel: showCarousel,
      onDaySelected: onDaySelected,
      onCreatePact: onCreatePact,
      onShowupTapped: onShowupTapped,
      onAbout: navigateToAbout,
    );
  }
}
