import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart'
    show
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoPageRoute,
        showCupertinoDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/dashboard/analytics/dashboard_screens.dart';
import 'package:habit_loop/features/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_screen.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/remote_config/providers/remote_config_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _creatingPact = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .logScreenView(const DashboardAnalyticsScreen()),
        );
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
        unawaited(ref.read(pactListViewModelProvider.notifier).load());
      }),
    );
  }

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
          ref
              .read(analyticsServiceProvider)
              .logScreenView(const DashboardAnalyticsScreen()),
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
        final maxActivePacts =
            ref.read(remoteConfigServiceProvider).getInt('max_active_pacts');
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
          ref
              .read(analyticsServiceProvider)
              .logScreenView(const DashboardAnalyticsScreen()),
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
