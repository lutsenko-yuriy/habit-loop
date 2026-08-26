import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/reminder/application/reconciliation_throttle.dart';

/// Non-rendering wrapper that fires `NotificationReconciliationService.reconcile()`
/// (HAB-254 WU3) on its two triggers: app foreground and `SyncService.pullCompleted`,
/// plus once on cold start (see [initState]). A shared [ReconciliationThrottle]
/// (re-entrancy lock + minimum interval) keeps all three from overlapping or
/// thrashing back-to-back. Wraps the whole app tree, inside the root
/// `ProviderScope` — see `main.dart`'s `MaterialApp.builder`.
class AppLifecycleReconciler extends ConsumerStatefulWidget {
  const AppLifecycleReconciler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleReconciler> createState() => _AppLifecycleReconcilerState();
}

class _AppLifecycleReconcilerState extends ConsumerState<AppLifecycleReconciler> with WidgetsBindingObserver {
  late final ReconciliationThrottle _throttle;
  StreamSubscription<void>? _pullCompletedSubscription;

  // Set when a trigger is blocked specifically because a run is still in
  // flight (checked via _throttle.isRunning, before the min-interval gate is
  // even consulted) — re-attempted once that run finishes, so e.g. a
  // pullCompleted landing mid-way through a foreground-triggered run isn't
  // silently dropped for good (audit finding, PR #412). A trigger blocked
  // purely by the min-interval (isRunning already false) is *not* retried —
  // it relies on the next natural trigger (foreground/pull) to catch up, an
  // accepted eventual-consistency trade-off for a best-effort mechanism.
  bool _pendingRetry = false;

  @override
  void initState() {
    super.initState();
    _throttle = ref.read(reconciliationThrottleProvider);
    WidgetsBinding.instance.addObserver(this);
    _pullCompletedSubscription = ref.read(syncServiceProvider).pullCompleted.listen((_) => _maybeReconcile());
    // didChangeAppLifecycleState only fires on a lifecycle *transition*
    // observed after addObserver runs above — if the platform already
    // delivered `resumed` before this widget mounted (racy on both cold
    // starts), that trigger is missed entirely and only pullCompleted would
    // ever fire, which requires a signed-in non-anonymous user online with a
    // closed circuit breaker. A one-shot post-frame check covers the plain
    // cold-start case unconditionally (audit finding, PR #412).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReconcile());
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
    if (_throttle.isRunning) {
      _pendingRetry = true;
      return;
    }
    if (!_throttle.tryStart(DateTime.now())) return;
    _runReconcile();
  }

  void _runReconcile() {
    unawaited(
      // reconcile() isn't formally no-throw like NotificationService — a
      // failure in a step outside its own per-pact try/catch (e.g. resolving
      // locale, reading the pending-notification list) must not propagate as
      // an unhandled root-zone error from this unawaited call (audit finding,
      // PR #412).
      ref.read(notificationReconciliationServiceProvider).reconcile().catchError((_) {}).whenComplete(() {
        _throttle.finish();
        if (_pendingRetry) {
          _pendingRetry = false;
          // forceStart, not tryStart/_maybeReconcile — this trigger was
          // already queued behind the re-entrancy lock, not newly arriving,
          // so it must not also be blocked by the min-interval gate.
          _throttle.forceStart(DateTime.now());
          _runReconcile();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
