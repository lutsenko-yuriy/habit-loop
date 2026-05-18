import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, CupertinoPageRoute, showCupertinoDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
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

  /// Guards the one-time [OnboardingPreferenceService.markOnboardingPassed]
  /// write so it is called at most once per session, even across multiple
  /// [build] calls before the async persist completes.
  bool _onboardingMarkedThisSession = false;

  /// The calendar date that was current the last time [load] was triggered.
  /// Stored as a date-only value (time component stripped) so midnight crossings
  /// are detected correctly regardless of the exact wall-clock time.
  DateTime? _lastLoadDate;

  @override
  void initState() {
    super.initState();
    // Capture the current date synchronously so that _lastLoadDate is never
    // null when didChangeAppLifecycleState fires — even if resumed fires in
    // the gap between addObserver and the microtask below.
    //
    // Reading todayProvider here (rather than using DateTime.now() directly)
    // ensures that test overrides are respected: if a test injects a fixed
    // date via ProviderScope, _lastLoadDate is initialised from that same
    // value so the guard comparison is consistent.
    //
    // Note: ref.read is safe in initState; what must be deferred is any call
    // that mutates provider state (e.g. load()), which is pushed to the
    // microtask below.
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
    // ref.read(todayProvider) captures the current wall-clock date for the
    // _lastLoadDate update.  The value is derived from the provider — not
    // DateTime.now() directly — so that test overrides (mutable date holders)
    // are respected and the guard compares against the same source of truth as
    // the load path.
    final today = _dateOnly(ref.read(todayProvider));
    if (today == _lastLoadDate) return;

    // Calendar date has changed since the last load — invalidate providers and
    // re-trigger the dashboard load so the calendar strip and showup list
    // reflect the new day without requiring the user to restart the app.
    //
    // Ordering note:
    //   1. _lastLoadDate = today   — update the guard first so any re-entrant
    //      resume event during the async load below is correctly no-op'd.
    //   2. ref.invalidate(todayProvider) — discard the cached DateTime value so
    //      the subsequent load() call inside DashboardViewModel._loadInner
    //      resolves a fresh DateTime.now() rather than the midnight-old value
    //      that was cached before the user went to background.  Both reads
    //      (this one and the next inside load()) resolve to the same calendar
    //      date because they are milliseconds apart.
    _lastLoadDate = today;
    ref.invalidate(todayProvider);
    ref.invalidate(hasActivePactsProvider);
    unawaited(
      ref.read(analyticsServiceProvider).logScreenView(const DashboardAnalyticsScreen()),
    );
    unawaited(ref.read(dashboardViewModelProvider.notifier).load());
    unawaited(ref.read(pactListViewModelProvider.notifier).load());
  }

  /// Strips the time component from [dt], returning a midnight-normalised date.
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardViewModelProvider);
    final hasActivePacts = ref.watch(hasActivePactsProvider);

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
        ref.invalidate(hasActivePactsProvider);
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
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

    // Read the onboarding flag synchronously.  Since SharedPreferences holds
    // values in memory after the first getInstance() call, this is a pure
    // in-memory lookup — no I/O on the main thread.
    final onboardingService = ref.read(onboardingPreferenceServiceProvider);
    final onboardingPassed = onboardingService.isOnboardingPassed;

    // Use valueOrNull so there is no separate loading state — during the brief
    // initial load hasPacts defaults to false. Errors are treated as "no pacts".
    final hasPacts = hasActivePacts.valueOrNull ?? false;

    // Anonymous user with no pacts — hasn't done anything yet.
    final isNewUser = isAnonymous && !hasPacts;

    // Show carousel when onboarding hasn't been passed yet AND the user is
    // either new or currently signing in.
    //
    // !onboardingPassed short-circuits on cold start for returning users so
    // hasActivePactsProvider's AsyncLoading state never causes a carousel flash.
    // isSigningIn keeps the carousel visible while pullRemoteChanges runs after
    // a Google sign-in, preventing a flash of an empty dashboard.
    final showCarousel = !onboardingPassed && (isNewUser || isSigningIn);

    // Write the onboarding-passed flag the first time the dashboard is shown.
    // The guard prevents multiple writes across build calls in the same session.
    // The write is deferred to a post-frame callback so build() stays a pure
    // function of state — side effects must not fire during the widget build phase.
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
      );
    }
    return DashboardPageAndroid(
      state: state,
      hasPacts: hasPacts,
      showCarousel: showCarousel,
      onDaySelected: onDaySelected,
      onCreatePact: onCreatePact,
      onShowupTapped: onShowupTapped,
    );
  }
}
