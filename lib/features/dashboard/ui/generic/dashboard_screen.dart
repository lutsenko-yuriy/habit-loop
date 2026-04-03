import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardViewModelProvider.notifier).load();
    });
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
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => const PactCreationScreen(),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PactCreationScreen(),
          ),
        );
      }
    }

    void onCreatePact() {
      final pactRepo = ref.read(pactRepositoryProvider);
      final l10n = AppLocalizations.of(context)!;
      pactRepo.getActivePacts().then((activePacts) async {
        if (!context.mounted) return;
        if (activePacts.length >= 3) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.tooManyPactsTitle),
              content: Text(l10n.tooManyPactsBody(activePacts.length)),
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
          );
          if (confirmed != true) return;
        }
        await navigateToPactCreation();
      });
    }

    return hasActivePacts.when(
      data: (hasPacts) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return DashboardPageIos(
            state: state,
            hasPacts: hasPacts,
            onDaySelected: onDaySelected,
            onCreatePact: onCreatePact,
          );
        }
        return DashboardPageAndroid(
          state: state,
          hasPacts: hasPacts,
          onDaySelected: onDaySelected,
          onCreatePact: onCreatePact,
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
