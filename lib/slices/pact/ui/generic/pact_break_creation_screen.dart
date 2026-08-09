import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_break_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_break_creation_page_ios.dart';

/// Screen orchestrator for the break-creation flow (HAB-195).
///
/// Callers must push this screen and `await` its result: `true` if a break
/// was created, so the caller can reload (e.g. Pact Detail's `activeBreak`).
///
/// [source] identifies the entry point for the `pact_break_started` analytics
/// event: `pact_detail` | `tail_zone_showup`.
class PactBreakCreationScreen extends ConsumerStatefulWidget {
  const PactBreakCreationScreen({super.key, required this.pactId, required this.source});

  final String pactId;
  final String source;

  @override
  ConsumerState<PactBreakCreationScreen> createState() => _PactBreakCreationScreenState();
}

class _PactBreakCreationScreenState extends ConsumerState<PactBreakCreationScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const PactBreakCreationAnalyticsScreen()),
        );
        unawaited(ref.read(pactBreakCreationViewModelProvider(widget.pactId).notifier).load());
      }),
    );
  }

  Future<void> _onSubmit(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(pactBreakCreationViewModelProvider(widget.pactId).notifier).submit(source: widget.source);
    if (success && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactBreakCreationViewModelProvider(widget.pactId));
    final notifier = ref.read(pactBreakCreationViewModelProvider(widget.pactId).notifier);

    void onClose() => Navigator.of(context).pop(false);
    void onSubmit() => unawaited(_onSubmit(context, ref));

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactBreakCreationPageIos(
        state: state,
        onStartDateChanged: notifier.setStartDate,
        onEndDateChanged: notifier.setEndDate,
        onUntilPactEndsChanged: notifier.setUntilPactEnds,
        onRationaleChanged: notifier.setRationale,
        onSubmit: onSubmit,
        onClose: onClose,
      );
    }
    return PactBreakCreationPageAndroid(
      state: state,
      onStartDateChanged: notifier.setStartDate,
      onEndDateChanged: notifier.setEndDate,
      onUntilPactEndsChanged: notifier.setUntilPactEnds,
      onRationaleChanged: notifier.setRationale,
      onSubmit: onSubmit,
      onClose: onClose,
    );
  }
}
