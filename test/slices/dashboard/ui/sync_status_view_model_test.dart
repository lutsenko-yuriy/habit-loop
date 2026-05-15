import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/auth/fake_auth_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  AuthService? authService,
  bool hasInternet = true,
  FakeAnalyticsService? analytics,
  FakeSyncService? syncService,
}) {
  return ProviderContainer(overrides: [
    authServiceProvider.overrideWithValue(
      authService ?? FakeAuthService(userId: 'user-1', isAnonymous: false),
    ),
    connectivityProvider.overrideWith(
      (ref) => Stream.value(hasInternet),
    ),
    analyticsServiceProvider.overrideWithValue(analytics ?? FakeAnalyticsService()),
    syncServiceProvider.overrideWithValue(syncService ?? FakeSyncService()),
  ]);
}

/// Subscribes to stream providers then waits for Riverpod to propagate.
///
/// Call this BEFORE emitting to [FakeAuthService] so the StreamProvider's
/// subscription is set up before the event fires. Pattern:
///   final settling = _settle(container);
///   auth.emitState(...);
///   await settling;
Future<void> _settle(ProviderContainer container) async {
  // Reading each .future subscribes to the underlying stream synchronously,
  // then waits for the first emission. Both providers must have settled before
  // reading the view model state.
  await Future.wait<void>([
    container.read(authStateChangesProvider.future).catchError((_) => const AuthState(userId: null, isAnonymous: true)),
    container.read(connectivityProvider.future).catchError((_) => true),
  ]);
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Fake auth service that throws on linkWithGoogle
// ---------------------------------------------------------------------------

class _ThrowingAuthService extends FakeAuthService {
  _ThrowingAuthService() : super(userId: 'user-1', isAnonymous: true);

  @override
  Future<void> linkWithGoogle() async {
    throw const AuthLinkException(code: 'account-exists-with-different-credential');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // State derivation
  // -------------------------------------------------------------------------

  group('SyncStatusViewModel state derivation', () {
    test('synced when linked user + CB closed + internet', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.synced);
    });

    test('notLinked when anonymous user + CB closed + internet', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: true);
      final container = _makeContainer(authService: auth);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: true);
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.notLinked);
    });

    test('degraded when linked user + CB halfOpen + internet', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      container.read(syncCircuitBreakerProvider.notifier).recordFailure();
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.degraded);
    });

    test('suspended when linked user + CB open + internet', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      // Drive CB to open: 1 failure → halfOpen, then 5 more → open
      final cb = container.read(syncCircuitBreakerProvider.notifier);
      for (var i = 0; i < 6; i++) {
        cb.recordFailure();
      }
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.suspended);
    });

    test('noInternet when connectivity is false', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, hasInternet: false);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.noInternet);
    });

    test('noInternet takes priority over notLinked', () async {
      final auth = FakeAuthService(userId: null, isAnonymous: true);
      final container = _makeContainer(authService: auth, hasInternet: false);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: null, isAnonymous: true);
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.noInternet);
    });

    test('connecting when auth is still loading', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth);
      addTearDown(container.dispose);
      // Settle connectivity only — do NOT emit auth state so it stays AsyncLoading.
      await container.read(connectivityProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(syncStatusViewModelProvider), SyncUiState.connecting);
    });

    test('noInternet takes priority over suspended', () async {
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, hasInternet: false);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      final cb = container.read(syncCircuitBreakerProvider.notifier);
      for (var i = 0; i < 6; i++) {
        cb.recordFailure();
      }
      await settling;

      expect(container.read(syncStatusViewModelProvider), SyncUiState.noInternet);
    });
  });

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  group('triggerManualSync', () {
    test('calls CB.triggerManualSync and fires ManualSyncTriggeredEvent', () async {
      final analytics = FakeAnalyticsService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, analytics: analytics);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      // Drive CB to open so triggerManualSync is meaningful
      final cb = container.read(syncCircuitBreakerProvider.notifier);
      for (var i = 0; i < 6; i++) {
        cb.recordFailure();
      }
      await settling;
      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.open);

      await container.read(syncStatusViewModelProvider.notifier).triggerManualSync();

      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.halfOpen);
      expect(analytics.loggedEvents.any((e) => e.name == 'manual_sync_triggered'), isTrue);
    });
  });

  group('linkWithGoogle', () {
    test('fires tapped + succeeded events on success', () async {
      final analytics = FakeAnalyticsService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: true);
      final container = _makeContainer(authService: auth, analytics: analytics);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: true);
      await settling;

      await container.read(syncStatusViewModelProvider.notifier).linkWithGoogle();

      expect(analytics.loggedEvents.any((e) => e.name == 'sign_in_with_google_tapped'), isTrue);
      expect(analytics.loggedEvents.any((e) => e.name == 'sign_in_with_google_succeeded'), isTrue);
      expect(analytics.loggedEvents.any((e) => e.name == 'sign_in_with_google_failed'), isFalse);
    });

    test('pulls remote changes and force-syncs all records on success', () async {
      final analytics = FakeAnalyticsService();
      final syncService = FakeSyncService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: true);
      final container = _makeContainer(authService: auth, analytics: analytics, syncService: syncService);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: true);
      await settling;

      await container.read(syncStatusViewModelProvider.notifier).linkWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(syncService.pullRemoteChangesCount, 1);
      expect(syncService.forceSyncAllCount, 1);
    });

    test('fires tapped + failed events and rethrows on AuthLinkException', () async {
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        authService: _ThrowingAuthService(),
        analytics: analytics,
      );
      addTearDown(container.dispose);
      // _ThrowingAuthService starts in isAnonymous:true state; emit it
      final throwing = container.read(authServiceProvider) as _ThrowingAuthService;
      final settling = _settle(container);
      throwing.emitState(userId: 'user-1', isAnonymous: true);
      await settling;

      await expectLater(
        container.read(syncStatusViewModelProvider.notifier).linkWithGoogle(),
        throwsA(isA<AuthLinkException>()),
      );

      expect(analytics.loggedEvents.any((e) => e.name == 'sign_in_with_google_tapped'), isTrue);
      expect(analytics.loggedEvents.any((e) => e.name == 'sign_in_with_google_failed'), isTrue);
      final failedEvent = analytics.loggedEvents.firstWhere((e) => e.name == 'sign_in_with_google_failed');
      expect(
        failedEvent.toParameters()['error_code'],
        'account-exists-with-different-credential',
      );
    });
  });

  group('signOut', () {
    test('calls auth signOut and fires SignOutTappedEvent', () async {
      final analytics = FakeAnalyticsService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, analytics: analytics);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      await container.read(syncStatusViewModelProvider.notifier).signOut();

      expect(auth.currentUserId, isNull);
      expect(analytics.loggedEvents.any((e) => e.name == 'sign_out_tapped'), isTrue);
    });
  });

  group('fullSync', () {
    test('fires full_sync_triggered with correct from_state', () async {
      final analytics = FakeAnalyticsService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, analytics: analytics);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;
      expect(container.read(syncStatusViewModelProvider), SyncUiState.synced);

      await container.read(syncStatusViewModelProvider.notifier).fullSync();

      final triggered = analytics.loggedEvents.where((e) => e.name == 'full_sync_triggered');
      expect(triggered, hasLength(1));
      expect(triggered.first.toParameters()['from_state'], 'synced');
    });

    test('calls forceSyncAll on the sync service', () async {
      final syncService = FakeSyncService();
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, syncService: syncService);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      await container.read(syncStatusViewModelProvider.notifier).fullSync();

      expect(syncService.forceSyncAllCount, 1);
    });

    test('fires full_sync_completed and returns 0 when forceSyncAll returns 0', () async {
      final analytics = FakeAnalyticsService();
      final syncService = FakeSyncService(); // forceSyncAllFailedCount defaults to 0
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, analytics: analytics, syncService: syncService);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      final result = await container.read(syncStatusViewModelProvider.notifier).fullSync();

      expect(result, equals(0));
      expect(analytics.loggedEvents.any((e) => e.name == 'full_sync_completed'), isTrue);
      expect(analytics.loggedEvents.any((e) => e.name == 'full_sync_failed'), isFalse);
    });

    test('fires full_sync_failed with records_failed and returns N when forceSyncAll returns N', () async {
      final analytics = FakeAnalyticsService();
      final syncService = FakeSyncService()..forceSyncAllFailedCount = 3;
      final auth = FakeAuthService(userId: 'u1', isAnonymous: false);
      final container = _makeContainer(authService: auth, analytics: analytics, syncService: syncService);
      addTearDown(container.dispose);
      final settling = _settle(container);
      auth.emitState(userId: 'u1', isAnonymous: false);
      await settling;

      final result = await container.read(syncStatusViewModelProvider.notifier).fullSync();

      expect(result, equals(3));
      expect(analytics.loggedEvents.any((e) => e.name == 'full_sync_failed'), isTrue);
      expect(analytics.loggedEvents.any((e) => e.name == 'full_sync_completed'), isFalse);
      final failedEvent = analytics.loggedEvents.firstWhere((e) => e.name == 'full_sync_failed');
      expect(failedEvent.toParameters()['records_failed'], 3);
    });
  });
}
