import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/slices/dashboard/analytics/sync_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

// Slice-local provider: lives here (not app_providers.dart) because it is
// scoped exclusively to the dashboard sync-status icon and dialog.
final syncStatusViewModelProvider = NotifierProvider.autoDispose<SyncStatusViewModel, SyncUiState>(
  SyncStatusViewModel.new,
);

class SyncStatusViewModel extends AutoDisposeNotifier<SyncUiState> {
  @override
  SyncUiState build() {
    // connectivityProvider emits bool (true = has internet); defaults to true
    // while loading so the UI never flashes noInternet on startup.
    final hasInternet = ref.watch(connectivityProvider).valueOrNull ?? true;
    final authAsync = ref.watch(authStateChangesProvider);
    final cbState = ref.watch(syncCircuitBreakerProvider);

    if (!hasInternet) {
      return SyncUiState.noInternet;
    }

    if (authAsync.isLoading) {
      return SyncUiState.connecting;
    }

    // authAsync.hasError collapses to notLinked: the stream re-emits on
    // reconnect, so this is a transient state with no meaningful action.
    final auth = authAsync.valueOrNull;
    if (auth == null || auth.isAnonymous) {
      return SyncUiState.notLinked;
    }

    return switch (cbState) {
      SyncCircuitBreakerState.open => SyncUiState.suspended,
      SyncCircuitBreakerState.halfOpen => SyncUiState.degraded,
      SyncCircuitBreakerState.closed => SyncUiState.synced,
    };
  }

  Future<void> triggerManualSync() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            ManualSyncTriggeredEvent(fromState: state.name),
          ),
    );
    ref.read(syncCircuitBreakerProvider.notifier).triggerManualSync();
  }

  Future<void> linkWithGoogle() async {
    // Capture all provider references before the await — Riverpod forbids
    // ref.read() after a watched dependency changes (which happens when the
    // auth state stream emits on successful sign-in).
    final analytics = ref.read(analyticsServiceProvider);
    final sync = ref.read(syncServiceProvider);
    unawaited(analytics.logEvent(SignInWithGoogleTappedEvent()));
    try {
      await ref.read(authServiceProvider).linkWithGoogle();
      unawaited(analytics.logEvent(SignInWithGoogleSucceededEvent()));
      // Pull historical data for the newly linked account and upload any dirty
      // records that accumulated while the user was anonymous / signed out.
      unawaited(sync.pullRemoteChanges());
      unawaited(sync.flushDirtyRecords());
    } on AuthLinkException catch (e) {
      unawaited(analytics.logEvent(SignInWithGoogleFailedEvent(errorCode: e.code)));
      rethrow;
    }
  }

  Future<void> signOut() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            SignOutTappedEvent(fromState: state.name),
          ),
    );
    await ref.read(authServiceProvider).signOut();
  }
}
