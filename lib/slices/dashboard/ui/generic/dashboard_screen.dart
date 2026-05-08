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

  /// The calendar date that was current the last time [load] was triggered.
  /// Stored as a date-only value (time component stripped) so midnight crossings
  /// are detected correctly regardless of the exact wall-clock time.
  DateTime? _lastLoadDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      Future.microtask(() {
        // Initialise _lastLoadDate from todayProvider so test overrides are
        // respected: if a test injects a fixed date, the guard must compare
        // against that same date rather than the wall-clock DateTime.now().
        _lastLoadDate = _dateOnly(ref.read(todayProvider));
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

    // Calendar date has changed since the last load — invalidate providers and
    // re-trigger the dashboard load so the calendar strip and showup list
    // reflect the new day without requiring the user to restart the app.
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

    return hasActivePacts.when(
      data: (hasPacts) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return DashboardPageIos(
            state: state,
            hasPacts: hasPacts,
            onDaySelected: onDaySelected,
            onCreatePact: onCreatePact,
            onShowupTapped: onShowupTapped,
          );
        }
        return DashboardPageAndroid(
          state: state,
          hasPacts: hasPacts,
          onDaySelected: onDaySelected,
          onCreatePact: onCreatePact,
          onShowupTapped: onShowupTapped,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong')),
      ),
    );
  }
}
