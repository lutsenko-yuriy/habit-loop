import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';

// A counting showup repository that records how many times getShowupsForDateRange
// is called. This lets tests verify whether load() ran again.
class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository() : super([]);

  int callCount = 0;

  @override
  Future<List<Showup>> getShowupsForDateRange(DateTime from, DateTime to) async {
    callCount++;
    return super.getShowupsForDateRange(from, to);
  }
}

/// A [StateProvider] used as a mutable date source in tests.
///
/// By overriding [todayProvider] to read from this provider, tests can mutate
/// the current date in-place (via `container.read(testDateSourceProvider.notifier).state = ...`)
/// without replacing the widget tree or rebuilding [_DashboardScreenState].
final _testDateSourceProvider = StateProvider<DateTime>((ref) => DateTime(2026, 3, 29));

/// Builds a [MaterialApp] whose [todayProvider] is backed by [_testDateSourceProvider].
///
/// Pass the [ProviderContainer] returned by [_makeContainer] — it gives the
/// test direct access to [_testDateSourceProvider] so the date can be updated
/// in place between lifecycle events.
Widget _buildAppFromContainer(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: DashboardScreen(),
    ),
  );
}

/// Creates a [ProviderContainer] wired with in-memory fakes and a mutable
/// [todayProvider] backed by [_testDateSourceProvider].
ProviderContainer _makeContainer({
  required DateTime initialDate,
  _CountingShowupRepository? showupRepo,
  FakeAnalyticsService? analyticsService,
}) {
  final pactRepo = InMemoryPactRepository([]);
  final repo = showupRepo ?? _CountingShowupRepository();
  final txService = InMemoryPactTransactionService(pactRepo, repo);

  final container = ProviderContainer(overrides: [
    pactRepositoryProvider.overrideWithValue(pactRepo),
    showupRepositoryProvider.overrideWithValue(repo),
    pactTransactionServiceProvider.overrideWithValue(txService),
    _testDateSourceProvider.overrideWith((ref) => initialDate),
    // todayProvider reads from the mutable date source so the test can
    // change the date in-place without rebuilding _DashboardScreenState.
    todayProvider.overrideWith((ref) => ref.watch(_testDateSourceProvider)),
    if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
  ]);
  return container;
}

void main() {
  group('DashboardScreen — date-change auto-refresh', () {
    testWidgets('same date on resume: load() is not called a second time', (tester) async {
      final countingRepo = _CountingShowupRepository();
      final container = _makeContainer(initialDate: DateTime(2026, 3, 29), showupRepo: countingRepo);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildAppFromContainer(container));
      await tester.pumpAndSettle();

      // Capture call count after the initial load.
      final callsAfterInitialLoad = countingRepo.callCount;
      expect(callsAfterInitialLoad, greaterThan(0), reason: 'Initial load should have called the repo');

      // Simulate the app being resumed with the SAME calendar date.
      // The date source is NOT changed, so todayProvider still returns the
      // same day — the guard must suppress a second load().
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // load() should NOT have been called again — same date.
      expect(
        countingRepo.callCount,
        equals(callsAfterInitialLoad),
        reason: 'Resume on same date must not trigger a second load()',
      );
    });

    testWidgets('different date on resume: load() is called again via observer path', (tester) async {
      final countingRepo = _CountingShowupRepository();
      final container = _makeContainer(initialDate: DateTime(2026, 3, 29), showupRepo: countingRepo);
      addTearDown(container.dispose);

      // Build the widget once — _DashboardScreenState is created and
      // _lastLoadDate is set to day1.  No widget tree rebuild happens after
      // this; the same state instance stays alive for the lifecycle event.
      await tester.pumpWidget(_buildAppFromContainer(container));
      await tester.pumpAndSettle();

      final callsAfterInitialLoad = countingRepo.callCount;
      expect(callsAfterInitialLoad, greaterThan(0));

      // Advance the date in-place without replacing the widget tree.
      // _DashboardScreenState._lastLoadDate still holds day1 (2026-03-29),
      // but the next ref.read(todayProvider) returns day2 (2026-03-30).
      container.read(_testDateSourceProvider.notifier).state = DateTime(2026, 3, 30);

      // Simulate resume on the same _DashboardScreenState instance.
      // didChangeAppLifecycleState must detect the date change and trigger
      // a fresh load() — this is the observer path under test.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        countingRepo.callCount,
        greaterThan(callsAfterInitialLoad),
        reason: 'Resume on a different date must trigger a fresh load() via the observer path',
      );
    });

    testWidgets('date changed on resume: analytics screen view is logged again', (tester) async {
      final analytics = FakeAnalyticsService();
      final countingRepo = _CountingShowupRepository();
      final container = _makeContainer(
        initialDate: DateTime(2026, 3, 29),
        showupRepo: countingRepo,
        analyticsService: analytics,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildAppFromContainer(container));
      await tester.pumpAndSettle();

      final screensAfterInitial = analytics.loggedScreens.where((s) => s.name == 'dashboard').length;

      // Advance the date in-place — same state instance, new date.
      container.read(_testDateSourceProvider.notifier).state = DateTime(2026, 3, 30);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        analytics.loggedScreens.where((s) => s.name == 'dashboard').length,
        greaterThan(screensAfterInitial),
        reason: 'A date-change resume must log the dashboard screen view again',
      );
    });

    testWidgets('same date on resume: analytics screen view is NOT logged again', (tester) async {
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(initialDate: DateTime(2026, 3, 29), analyticsService: analytics);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildAppFromContainer(container));
      await tester.pumpAndSettle();

      final screensAfterInitial = analytics.loggedScreens.where((s) => s.name == 'dashboard').length;

      // Do NOT change the date — same-day resume must be a no-op.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        analytics.loggedScreens.where((s) => s.name == 'dashboard').length,
        equals(screensAfterInitial),
        reason: 'Resume on same date must NOT log an extra screen view',
      );
    });
  });
}
