import 'dart:async' show unawaited;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/slices/dashboard/analytics/sync_analytics_events.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

final syncStatusViewModelProvider = NotifierProvider.autoDispose<SyncStatusViewModel, SyncUiState>(
  SyncStatusViewModel.new,
);

class SyncStatusViewModel extends AutoDisposeNotifier<SyncUiState> {
  @override
  SyncUiState build() {
    final connectivity = ref.watch(connectivityProvider).valueOrNull ?? [ConnectivityResult.wifi];
    final authAsync = ref.watch(authStateChangesProvider);
    final cbState = ref.watch(syncCircuitBreakerProvider);

    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      return SyncUiState.noInternet;
    }

    if (authAsync.isLoading) {
      return SyncUiState.connecting;
    }

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
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(analytics.logEvent(SignInWithGoogleTappedEvent()));
    try {
      await ref.read(authServiceProvider).linkWithGoogle();
      unawaited(analytics.logEvent(SignInWithGoogleSucceededEvent()));
    } on FirebaseAuthException catch (e) {
      unawaited(analytics.logEvent(SignInWithGoogleFailedEvent(errorCode: e.code)));
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
