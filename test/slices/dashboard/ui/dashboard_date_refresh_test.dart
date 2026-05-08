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

Widget _buildApp({
  required DateTime today,
  FakeAnalyticsService? analyticsService,
  _CountingShowupRepository? showupRepo,
}) {
  final pactRepo = InMemoryPactRepository([]);
  final repo = showupRepo ?? _CountingShowupRepository();
  final txService = InMemoryPactTransactionService(pactRepo, repo);

  return ProviderScope(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(repo),
      pactTransactionServiceProvider.overrideWithValue(txService),
      todayProvider.overrideWithValue(today),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
    ],
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

void main() {
  group('DashboardScreen — date-change auto-refresh', () {
    testWidgets('same date on resume: load() is not called a second time', (tester) async {
      final today = DateTime(2026, 3, 29);
      final countingRepo = _CountingShowupRepository();

      await tester.pumpWidget(_buildApp(today: today, showupRepo: countingRepo));
      await tester.pumpAndSettle();

      // Capture call count after the initial load.
      final callsAfterInitialLoad = countingRepo.callCount;
      expect(callsAfterInitialLoad, greaterThan(0), reason: 'Initial load should have called the repo');

      // Simulate the app being resumed with the SAME calendar date.
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

    testWidgets('different date on resume: load() is called again', (tester) async {
      final day1 = DateTime(2026, 3, 29);
      final day2 = DateTime(2026, 3, 30); // next day

      final countingRepo = _CountingShowupRepository();

      // Build with day1 as today.
      await tester.pumpWidget(_buildApp(today: day1, showupRepo: countingRepo));
      await tester.pumpAndSettle();

      final callsAfterInitialLoad = countingRepo.callCount;
      expect(callsAfterInitialLoad, greaterThan(0));

      // Rebuild with day2 — this updates the todayProvider override so that the
      // next ref.read(todayProvider) inside load() returns the new date.
      await tester.pumpWidget(_buildApp(today: day2, showupRepo: countingRepo));
      await tester.pump();

      // Simulate resume — the screen must detect the date has changed.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // load() should have been called at least once more than after the initial
      // load on day1.
      expect(
        countingRepo.callCount,
        greaterThan(callsAfterInitialLoad),
        reason: 'Resume on a different date must trigger a fresh load()',
      );
    });

    testWidgets('date changed on resume: analytics screen view is logged again', (tester) async {
      final day1 = DateTime(2026, 3, 29);
      final day2 = DateTime(2026, 3, 30);
      final analytics = FakeAnalyticsService();
      final countingRepo = _CountingShowupRepository();

      await tester.pumpWidget(_buildApp(today: day1, analyticsService: analytics, showupRepo: countingRepo));
      await tester.pumpAndSettle();

      final screensAfterInitial = analytics.loggedScreens.where((s) => s.name == 'dashboard').length;

      // Rebuild with day2.
      await tester.pumpWidget(_buildApp(today: day2, analyticsService: analytics, showupRepo: countingRepo));
      await tester.pump();

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
      final today = DateTime(2026, 3, 29);
      final analytics = FakeAnalyticsService();

      await tester.pumpWidget(_buildApp(today: today, analyticsService: analytics));
      await tester.pumpAndSettle();

      final screensAfterInitial = analytics.loggedScreens.where((s) => s.name == 'dashboard').length;

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
