import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/reminder/application/reconciliation_throttle.dart';
import 'package:habit_loop/slices/reminder/ui/generic/app_lifecycle_reconciler.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../../infrastructure/sync/fake_sync_service.dart';

// Delays getActivePacts() so a test can observe a reconcile() call still
// in flight when a second trigger fires.
class _DelayedPactRepository implements PactRepository {
  _DelayedPactRepository(this._delegate, this._delay);

  final PactRepository _delegate;
  final Duration _delay;
  int callCount = 0;

  @override
  Future<List<Pact>> getActivePacts() async {
    callCount++;
    await Future<void>.delayed(_delay);
    return _delegate.getActivePacts();
  }

  @override
  Future<List<Pact>> getAllPacts() => _delegate.getAllPacts();
  @override
  Future<Pact?> getPactById(String id) => _delegate.getPactById(id);
  @override
  Future<Pact?> getSuccessor(String pactId) => _delegate.getSuccessor(pactId);
  @override
  Future<void> savePact(Pact pact) => _delegate.savePact(pact);
  @override
  Future<void> updatePact(Pact pact) => _delegate.updatePact(pact);
  @override
  Future<void> deletePact(String id) => _delegate.deletePact(id);
  @override
  Future<void> archivePact(String id, bool archived) => _delegate.archivePact(id, archived);
}

// Throws on every call — used to prove a reconcile() failure never crashes
// the widget tree.
class _ThrowingPactRepository implements PactRepository {
  @override
  Future<List<Pact>> getActivePacts() async => throw StateError('simulated repository failure');
  @override
  Future<List<Pact>> getAllPacts() async => [];
  @override
  Future<Pact?> getPactById(String id) async => null;
  @override
  Future<Pact?> getSuccessor(String pactId) async => null;
  @override
  Future<void> savePact(Pact pact) async {}
  @override
  Future<void> updatePact(Pact pact) async {}
  @override
  Future<void> deletePact(String id) async {}
  @override
  Future<void> archivePact(String id, bool archived) async {}
}

Pact _makePact() => Pact(
      id: 'pact-1',
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      showupDuration: const Duration(minutes: 20),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
      reminderOffset: const Duration(minutes: 10),
      createdAt: DateTime(2026, 1, 1),
    );

Showup _makeShowup() => Showup(
      id: 'showup-1',
      pactId: 'pact-1',
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
      duration: const Duration(minutes: 20),
      status: ShowupStatus.pending,
    );

void main() {
  late FakeNotificationService notifications;
  late FakeSyncService syncService;
  late InMemoryPactRepository pactRepo;
  late InMemoryShowupRepository showupRepo;

  Future<List<Override>> buildOverrides({PactRepository? pactRepository}) async {
    return [
      ...await AppContainer.overrides(
        pactRepository: pactRepository ?? pactRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(pactRepo, showupRepo),
        pactBreakRepository: InMemoryPactBreakRepository(),
        analyticsService: FakeAnalyticsService(),
        remoteConfigService: FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': false}),
        notificationService: notifications,
        localePreferenceService: FakeLocalePreferenceService(),
      ),
      syncServiceProvider.overrideWithValue(syncService),
    ];
  }

  setUp(() {
    notifications = FakeNotificationService();
    syncService = FakeSyncService();
    pactRepo = InMemoryPactRepository([_makePact()]);
    showupRepo = InMemoryShowupRepository([_makeShowup()]);
  });

  Future<void> pumpReconciler(WidgetTester tester, {required List<Override> overrides}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: AppLifecycleReconciler(child: SizedBox())),
      ),
    );
  }

  testWidgets('reconciles once on cold start, before any explicit trigger', (tester) async {
    await pumpReconciler(tester, overrides: await buildOverrides());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifications.scheduledReminders, isNotEmpty);
  });

  testWidgets('reconciles on app foreground', (tester) async {
    await pumpReconciler(
      tester,
      overrides: [
        ...await buildOverrides(),
        reconciliationThrottleProvider.overrideWithValue(ReconciliationThrottle(minInterval: Duration.zero)),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    notifications.reset();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifications.scheduledReminders, isNotEmpty);
  });

  testWidgets('reconciles on SyncService.pullCompleted', (tester) async {
    await pumpReconciler(
      tester,
      overrides: [
        ...await buildOverrides(),
        reconciliationThrottleProvider.overrideWithValue(ReconciliationThrottle(minInterval: Duration.zero)),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    notifications.reset();

    syncService.emitPullCompleted();
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifications.scheduledReminders, isNotEmpty);
  });

  testWidgets('a second trigger within the throttle interval makes no additional call', (tester) async {
    await pumpReconciler(tester, overrides: await buildOverrides());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final countAfterColdStart = notifications.scheduledReminders.length;
    expect(countAfterColdStart, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifications.scheduledReminders.length, equals(countAfterColdStart));
  });

  testWidgets('a trigger blocked by an in-flight run is retried once that run finishes', (tester) async {
    final slowRepo = _DelayedPactRepository(pactRepo, const Duration(milliseconds: 200));
    // Default (production) throttle — the in-flight run's own completion is
    // what should trigger the retry here, not an interval reset (that path
    // is covered by the "second trigger within the throttle interval" test
    // above, which is deliberately *not* retried).
    await pumpReconciler(tester, overrides: await buildOverrides(pactRepository: slowRepo));
    // Cold-start's reconcile() call is now in flight (delayed inside
    // getActivePacts()) — not yet resolved.
    await tester.pump();
    expect(slowRepo.callCount, equals(1));

    // A second trigger arrives while the first is still running — blocked by
    // the re-entrancy lock, not the interval — so it must be retried once
    // the in-flight run finishes rather than dropped for good.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200)); // in-flight run finishes, retry fires
    await tester.pump(const Duration(milliseconds: 200)); // retried run finishes

    expect(slowRepo.callCount, equals(2));
  });

  testWidgets('a reconcile() failure does not crash the widget tree', (tester) async {
    await pumpReconciler(tester, overrides: await buildOverrides(pactRepository: _ThrowingPactRepository()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(AppLifecycleReconciler), findsOneWidget);
  });

  testWidgets('dispose removes the lifecycle observer and cancels the pullCompleted subscription', (tester) async {
    await pumpReconciler(
      tester,
      overrides: [
        ...await buildOverrides(),
        reconciliationThrottleProvider.overrideWithValue(ReconciliationThrottle(minInterval: Duration.zero)),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    notifications.reset();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));

    // Neither trigger should reach a disposed widget's state.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    syncService.emitPullCompleted();
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifications.scheduledReminders, isEmpty);
  });
}
