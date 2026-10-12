import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/navigation/checklister_callback_navigator.dart';
import 'package:habit_loop/navigation/checklister_run_handler.dart';
import 'package:habit_loop/navigation/checklister_selection_handler.dart';
import 'package:habit_loop/navigation/notification_navigator.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_signals.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_signals.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

/// Non-rendering wrapper that subscribes once to `incomingLinkServiceProvider` and
/// routes Checklister callbacks to [ChecklisterCallbackNavigator].
class ChecklisterCallbackListener extends ConsumerStatefulWidget {
  const ChecklisterCallbackListener({super.key, required this.child, this.navigatorKey});

  final Widget child;

  /// Used to open the showup detail for a run callback when none is open; `null` disables that.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<ChecklisterCallbackListener> createState() => _ChecklisterCallbackListenerState();
}

class _ChecklisterCallbackListenerState extends ConsumerState<ChecklisterCallbackListener> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ChecklisterCallbackNavigator(
      onSelection: _selectionHandler().call,
      onRun: _runHandler().call,
    ).listen(
      ref.read(incomingLinkServiceProvider).links,
    );
  }

  ChecklisterSelectionHandler _selectionHandler() => ChecklisterSelectionHandler(
        service: ref.read(checklistServiceProvider),
        onNoChecklists: (pactId) {
          if (mounted) ref.read(checklistNoChecklistsNoticeProvider(pactId).notifier).state = true;
        },
        onChanged: () {
          if (mounted) ref.read(checklistSectionRefreshSignalProvider.notifier).update((n) => n + 1);
        },
      );

  ChecklisterRunHandler _runHandler() => ChecklisterRunHandler(
        service: ref.read(checklistServiceProvider),
        onFinished: (showupId, outcome) {
          if (!mounted) return;
          ref.read(checklistRunFinishedNoticeProvider(showupId).notifier).state = outcome;
          // An open showup detail consumes the notice itself; otherwise (cold start) open one.
          final navigatorKey = widget.navigatorKey;
          if (navigatorKey == null || ref.exists(showupDetailViewModelProvider(showupId))) return;
          void push() => unawaited(NotificationNavigator.navigateToShowup(
                navigatorKey: navigatorKey,
                showupId: showupId,
                onReturn: () {
                  if (mounted) ref.read(dashboardRefreshSignalProvider.notifier).state++;
                },
              ));
          // Cold start: the navigator may not be mounted yet.
          if (navigatorKey.currentState != null) {
            push();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => push());
          }
        },
      );

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
