import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

ProviderContainer _makeContainer() {
  final pactRepo = InMemoryPactRepository();
  final showupRepo = InMemoryShowupRepository();
  return ProviderContainer(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      pactTransactionServiceProvider.overrideWithValue(InMemoryPactTransactionService(pactRepo, showupRepo)),
      todayProvider.overrideWithValue(DateTime(2026, 6, 7)),
    ],
  );
}

void main() {
  group('dashboardRefreshSignalProvider', () {
    test('starts at 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(dashboardRefreshSignalProvider), 0);
    });

    test('increments on update', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(dashboardRefreshSignalProvider.notifier).update((n) => n + 1);
      expect(container.read(dashboardRefreshSignalProvider), 1);
    });
  });

  group('DashboardViewModel refresh signal integration', () {
    test('incrementing the signal triggers a dashboard reload', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Build VM — this registers the refresh signal listener.
      container.read(dashboardViewModelProvider);
      // Initial load is async; wait for it.
      await container.read(dashboardViewModelProvider.notifier).load();
      expect(container.read(dashboardViewModelProvider).isLoading, isFalse);

      // Simulate pact creation: fire the refresh signal.
      container.read(dashboardRefreshSignalProvider.notifier).update((n) => n + 1);

      // The VM reacts asynchronously — wait for the load triggered by the signal.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dashboardViewModelProvider).isLoading, isFalse);
      expect(container.read(dashboardViewModelProvider).calendarDays, hasLength(7));
    });
  });
}
