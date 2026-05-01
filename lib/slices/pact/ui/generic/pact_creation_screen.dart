import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';

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

    Future<void> onSubmit() async {
      await vm.submit();
      if (context.mounted) {
        ref.invalidate(hasActivePactsProvider);
        unawaited(ref.read(dashboardViewModelProvider.notifier).load());
        Navigator.of(context).pop();
      }
    }

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
        onNext: vm.nextStep,
        onBack: vm.previousStep,
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
      onNext: vm.nextStep,
      onBack: vm.previousStep,
      onSubmit: onSubmit,
    );
  }
}
