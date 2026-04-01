import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/dashboard/ui/android/dashboard_page_android.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/dashboard/ui/ios/dashboard_page_ios.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';

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

    void onCreatePact() {
      ref.invalidate(pactCreationViewModelProvider);
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
