import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';

class PactCreationScreen extends ConsumerStatefulWidget {
  const PactCreationScreen({super.key});

  @override
  ConsumerState<PactCreationScreen> createState() => _PactCreationScreenState();
}

class _PactCreationScreenState extends ConsumerState<PactCreationScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const PactCreationAnalyticsScreen()),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactCreationViewModelProvider);
    final vm = ref.read(pactCreationViewModelProvider.notifier);

    // TODO(WU2): read commitmentVariant from RemoteConfigService.
    // For now the screen passes 'button' (control variant) until the PageView
    // wizard and commitment dialog are wired up in WU2.
    Future<void> onSubmit() async {
      await vm.submit(commitmentVariant: 'button');
      if (context.mounted) {
        ref.invalidate(hasActivePactsProvider);
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
        Navigator.of(context).pop();
      }
    }

    // TODO(WU2): onNext/onBack are replaced by the PageView swipe gesture.
    // These are no-ops until the PageView container is built in WU2.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactCreationPageIos(
        state: state,
        onHabitNameChanged: vm.setHabitName,
        onStartDateChanged: vm.setStartDate,
        onEndDateChanged: vm.setEndDate,
        onShowupDurationChanged: vm.setShowupDuration,
        onScheduleTypeChanged: vm.setScheduleType,
        onScheduleChanged: vm.setSchedule,
        onReminderOffsetChanged: vm.setReminderOffset,
        onClearReminder: vm.clearReminderOffset,
        onCommitmentChanged: vm.setCommitmentAccepted,
        onNext: () {}, // TODO(WU2): remove; PageView handles navigation
        onBack: () {}, // TODO(WU2): remove; PageView handles navigation
        onSubmit: onSubmit,
      );
    }

    return PactCreationPageAndroid(
      state: state,
      onHabitNameChanged: vm.setHabitName,
      onStartDateChanged: vm.setStartDate,
      onEndDateChanged: vm.setEndDate,
      onShowupDurationChanged: vm.setShowupDuration,
      onScheduleTypeChanged: vm.setScheduleType,
      onScheduleChanged: vm.setSchedule,
      onReminderOffsetChanged: vm.setReminderOffset,
      onClearReminder: vm.clearReminderOffset,
      onCommitmentChanged: vm.setCommitmentAccepted,
      onNext: () {}, // TODO(WU2): remove; PageView handles navigation
      onBack: () {}, // TODO(WU2): remove; PageView handles navigation
      onSubmit: onSubmit,
    );
  }
}
