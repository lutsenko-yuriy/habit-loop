import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/reminder/application/reconciliation_throttle.dart';

/// Non-rendering wrapper that fires `NotificationReconciliationService.reconcile()`
/// (HAB-254 WU3) on its two triggers: app foreground and `SyncService.pullCompleted`.
/// A shared [ReconciliationThrottle] (re-entrancy lock + minimum interval) keeps
/// both triggers from overlapping or thrashing back-to-back. Wraps the whole app
/// tree, inside the root `ProviderScope` — see `main.dart`'s `MaterialApp.builder`.
class AppLifecycleReconciler extends ConsumerStatefulWidget {
  const AppLifecycleReconciler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleReconciler> createState() => _AppLifecycleReconcilerState();
}

class _AppLifecycleReconcilerState extends ConsumerState<AppLifecycleReconciler> with WidgetsBindingObserver {
  final _throttle = ReconciliationThrottle();
  StreamSubscription<void>? _pullCompletedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pullCompletedSubscription = ref.read(syncServiceProvider).pullCompleted.listen((_) => _maybeReconcile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pullCompletedSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _maybeReconcile();
  }

  void _maybeReconcile() {
    if (!_throttle.tryStart(DateTime.now())) return;
    unawaited(
      ref.read(notificationReconciliationServiceProvider).reconcile().whenComplete(_throttle.finish),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
